//
//  FreehandCropEditorView.swift
//  DocScanner
//
//  Created by Zara Maraj on 3/13/26.
//
import SwiftUI
import UIKit

struct FreehandCropEditorView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onUseSelection: (UIImage) -> Void

    @State private var points: [CGPoint] = []
    @State private var showError = false
    @State private var errorMessage = ""

    private var displayImage: UIImage {
        image.normalizedImage()
    }

    var body: some View {
        GeometryReader { geo in
            let imageRect = aspectFitRect(for: displayImage.size, in: geo.size)

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                FreehandOverlay(points: points)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let p = value.location
                                guard imageRect.contains(p) else { return }

                                if points.isEmpty {
                                    points = [p]
                                } else {
                                    let last = points[points.count - 1]
                                    let dx = p.x - last.x
                                    let dy = p.y - last.y
                                    let distance = sqrt(dx * dx + dy * dy)

                                    if distance > 2 {
                                        points.append(p)
                                    }
                                }
                            }
                    )

                VStack {
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .foregroundColor(.white)
                        .cornerRadius(12)

                        Spacer()

                        Button("Clear") {
                            points.removeAll()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    Spacer()

                    VStack(spacing: 12) {
                        Text("Draw a closed shape around the area you want")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Button("Use Selection") {
                            useSelection(imageRect: imageRect)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .padding(.bottom, 28)
                }
            }
        }
        .alert("Crop Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func useSelection(imageRect: CGRect) {
        guard points.count >= 3 else {
            errorMessage = "Draw around the region first."
            showError = true
            return
        }

        let imagePoints = points.map { viewPoint in
            mapPointFromViewToImage(viewPoint, imageRect: imageRect, imageSize: displayImage.size)
        }

        guard let cropped = cropImageWithPolygon(displayImage, polygonPoints: imagePoints) else {
            errorMessage = "Failed to crop the selected region."
            showError = true
            return
        }

        onUseSelection(cropped)
    }
}

private struct FreehandOverlay: View {
    let points: [CGPoint]

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }

            var path = Path()
            path.move(to: points[0])

            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(path, with: .color(.yellow), lineWidth: 3)
        }
        .allowsHitTesting(false)
    }
}

private func aspectFitRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
    let imageAspect = imageSize.width / imageSize.height
    let containerAspect = containerSize.width / containerSize.height

    let width: CGFloat
    let height: CGFloat

    if imageAspect > containerAspect {
        width = containerSize.width
        height = width / imageAspect
    } else {
        height = containerSize.height
        width = height * imageAspect
    }

    let x = (containerSize.width - width) / 2
    let y = (containerSize.height - height) / 2

    return CGRect(x: x, y: y, width: width, height: height)
}

private func mapPointFromViewToImage(_ point: CGPoint, imageRect: CGRect, imageSize: CGSize) -> CGPoint {
    let x = ((point.x - imageRect.minX) / imageRect.width) * imageSize.width
    let y = ((point.y - imageRect.minY) / imageRect.height) * imageSize.height
    return CGPoint(x: x, y: y)
}

private func cropImageWithPolygon(_ image: UIImage, polygonPoints: [CGPoint]) -> UIImage? {
    guard polygonPoints.count >= 3 else { return nil }

    let safePoints = polygonPoints.map {
        CGPoint(
            x: min(max($0.x, 0), image.size.width),
            y: min(max($0.y, 0), image.size.height)
        )
    }

    let bezier = UIBezierPath()
    bezier.move(to: safePoints[0])
    for point in safePoints.dropFirst() {
        bezier.addLine(to: point)
    }
    bezier.close()

    let bounds = bezier.bounds.integral
    guard bounds.width > 1, bounds.height > 1 else { return nil }

    let renderer = UIGraphicsImageRenderer(size: bounds.size)

    let cropped = renderer.image { _ in
        UIColor.clear.setFill()
        UIRectFill(CGRect(origin: .zero, size: bounds.size))

        let translatedPath = UIBezierPath()
        translatedPath.move(to: CGPoint(x: safePoints[0].x - bounds.minX, y: safePoints[0].y - bounds.minY))
        for point in safePoints.dropFirst() {
            translatedPath.addLine(to: CGPoint(x: point.x - bounds.minX, y: point.y - bounds.minY))
        }
        translatedPath.close()

        translatedPath.addClip()

        image.draw(at: CGPoint(x: -bounds.minX, y: -bounds.minY))
    }

    return cropped
}

extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
