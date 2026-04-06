# 📲 DocInsight AI
### A Multimodal Mobile System for Intelligent Document Simplification

<div align="center">
<img width="220" src="https://github.com/user-attachments/assets/bcb21d20-9072-4be5-a07d-4aa4f930be80" />
</div>

---

## Overview

DocInsight AI is an AI-powered iOS mobile application that transforms complex, hard-to-read documents into clear, accessible summaries and visual outputs. Users can photograph a document, select an image from their library, or record audio and receive an instantly simplified version in the most appropriate format: plain text, a chart, a table, a flowchart, or a structured voice summary.

The system was built as part of the LREU program at Florida International University, motivated by the growing accessibility gap between the complexity of everyday documents and the average reading level of the general public.

---

## Motivation & Background

Studies show that a significant portion of American adults struggle to comprehend complex documents, including medical consent forms, legal contracts, government forms, and academic papers. These comprehension barriers have real-world consequences: missed medical diagnoses, misunderstood legal agreements, and reduced educational equity.

Existing solutions are largely desktop-based, require technical expertise, or return generic summaries without adapting the output format to the content type. DocScan addresses this gap by:

- Running entirely on a smartphone with a simple three-tap interface
- Automatically detecting the best output format for each document type
- Supporting voice input for audio content like meetings and lectures
- Using state-of-the-art large language models for high-quality simplification

---

## Screenshots

<div align="center">
  <img width="180" src="https://github.com/user-attachments/assets/07011e46-b2e7-41c6-877f-93534edc8126" />
  &nbsp;&nbsp;
  <img width="180" src="https://github.com/user-attachments/assets/6a71e36d-f80f-4fef-8daa-030f4b59309d" />
  &nbsp;&nbsp;
  <img width="180" src="https://github.com/user-attachments/assets/980aacf1-8dfd-4551-b8c0-47a55293508b" />
  &nbsp;&nbsp;
  <img width="180" src="https://github.com/user-attachments/assets/3b08f46d-bc9e-4859-b963-0369722edcc1" />
</div>

<div align="center">
  <sub>Home Screen &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Scanning &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Result — Text &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Result — Chart</sub>
</div>

---

## System Architecture

<div align="center">
  <img width="2541" height="504" alt="image" src="https://github.com/user-attachments/assets/0e9aaab0-1b35-4dde-9807-b6d18f03cb35" />
</div>

The system is divided into three layers:

### Input Layer (iOS — Swift/SwiftUI)
- **Camera capture** via `UIImagePickerController`
- **Photo library** access via `PhotosUI` / `PHPickerViewController`
- **Voice recording** via `AVFoundation` / `AVAudioRecorder`
- Multipart form upload over HTTPS to the backend server

### Backend Processing Engine (Python — Flask)
- **Transport**: REST API over Flask, tunneled via ngrok for remote access
- **Text extraction**: `pytesseract` (Tesseract OCR, PSM 6 layout mode) for images; `OpenAI Whisper` (base model, local CPU inference) for audio
- **AI analysis**: `Groq API` running `Llama 3.3-70B-Versatile` for document analysis and summarization (temperature: 0.2, max_tokens: 1500)
- **Output detection**: Classifier selects between `text`, `chart`, `table`, or `flowchart` based on document content
- **Visual generation**: `matplotlib` and `networkx` render charts, tables, and flowcharts, returned as base64-encoded PNG in the JSON response

### Output Layer (iOS)
- Plain text summary rendered in a scrollable card
- Voice results displayed as animated bullet points
- Charts, tables, and flowcharts rendered as inline images
- Full scan history saved locally via `UserDefaults`
- Share sheet for exporting results

---

## Methodology

### Document Processing Pipeline
1. User captures or selects a document on iPhone
2. Image is JPEG-compressed and uploaded via multipart form POST
3. Server extracts text using Tesseract OCR
4. Extracted text is sent to Groq (Llama 3.3-70B) with a structured prompt
5. Model returns a JSON response specifying output type and content
6. If visual output is needed, matplotlib generates the graphic
7. Result is returned to the iPhone and rendered in the UI

### Audio Processing Pipeline
1. User records audio using the built-in microphone
2. M4A file is uploaded to the `/upload-audio` endpoint
3. Whisper transcribes the audio locally (no external API)
4. Transcript is sent to Groq for structured summarization
5. Summary is returned as bullet points on the result screen

### Prompt Engineering
The system uses two specialized prompts:
- **Document prompt**: Instructs the model to analyze content and select the optimal output format with explicit rules for when to use each type, quality standards, and formatting requirements
- **Audio prompt**: Specialized for spoken content, capturing action items, decisions, key points, and follow-ups from meetings, lectures, and voice notes

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS App | Swift, SwiftUI, AVFoundation, PhotosUI |
| Backend | Python 3.14, Flask |
| AI / LLM | Groq API — Llama 3.3-70B-Versatile |
| OCR | Tesseract (pytesseract) |
| Speech-to-Text | OpenAI Whisper (local, base model) |
| Visualization | matplotlib, networkx |
| Tunneling | ngrok |
| PDF Parsing | PyMuPDF |

---

## How to Run

### Prerequisites
- Mac with Xcode installed
- iPhone (iOS 17+)
- Python 3.11+
- Homebrew
- A free Groq API key from [console.groq.com](https://console.groq.com)
- ngrok account (free) from [ngrok.com](https://ngrok.com)

---

### 1. Clone the repo
```bash
git clone https://github.com/YOUR_USERNAME/DocInsightAI.git
cd DocInsightAI
```

---

### 2. Set up the Python server
```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Install system dependencies:
```bash
brew install tesseract ffmpeg
```

Create a `.env` file in the `server/` folder:
Start the server:
```bash
python app.py
```
---

### 3. Start ngrok tunnel
```bash
ngrok http 3000
```

Copy the `https://` URL and update this line in `ios/DocScanner/ContentView.swift`:
```swift
let baseURL = "https://YOUR-NGROK-URL-HERE"
```
---

### 4. Run the iOS app

Open `ios/DocScanner.xcodeproj` in Xcode, select your iPhone as the target, and press ▶

---

## Evaluation

Two evaluation methods were used to assess DocInsight AI's effectiveness: a human user study measuring comprehension improvement, and an AI-based readability evaluation using Flesch Reading Ease scores.

---

### Human User Study

Participants rated their comprehension level of each document type before and after using DocInsight AI on a scale of 1 (Very Difficult) to 5 (Easy).

| Document Type | Before DocInsight AI | After DocInsight AI | Improvement |
|:-------------:|:--------------------:|:-------------------:|:-----------:|
| Legal | 2 | 4 | +2 |
| Medical | 1 | 4 | +3 |
| Academic | 3 | 5 | +2 |
| Scientific | 3 | 4 | +1 |

---

### AI Evaluation — Flesch Reading Ease Score

Flesch Reading Ease scores were computed on the original documents and the simplified outputs generated by DocInsight AI. Higher scores indicate easier readability (0 = very difficult, 100 = very easy). Standard readable text falls between 60–70.

| Document Type | Before DocInsight AI | After DocInsight AI | Improvement |
|:-------------:|:--------------------:|:-------------------:|:-----------:|
| Legal | 18 | 58 | +40 |
| Medical | 22 | 55 | +33 |
| Academic | 15 | 52 | +37 |
| Scientific | 28 | 60 | +32 |

---

### Key Findings

- Medical documents showed the greatest comprehension improvement among human participants (+3 points)
- All document types crossed the 50+ Flesch score threshold after simplification, reaching the "fairly easy to read" range
- Academic documents saw the largest absolute readability gain (+37 Flesch points)
- Human comprehension ratings improved by an average of **+2 points** across all document types
- AI readability scores improved by an average of **+35.5 Flesch points** across all document types

---

## Future Work

- Image generation for visual concepts using Hugging Face or Stable Diffusion
- Expanded LLM support — OpenAI GPT-4o and Anthropic Claude as selectable backends
- Larger user studies scaled to 25+ participants
- Offline mode with a bundled local model
- Native PDF rendering and page-by-page processing

---

## Author

**Zara Maraj**  
Florida International University
Spring 2026

---
