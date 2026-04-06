from flask import Flask, request, jsonify
import os
from dotenv import load_dotenv
from datetime import datetime
from groq import Groq
from PIL import Image
import pytesseract
import json
import re
import whisper

app = Flask(__name__)

UPLOAD_FOLDER = "uploads"
OUTPUT_FOLDER = "outputs"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

load_dotenv()
groq_client = Groq(api_key=os.getenv("GROQ_KEY"))

print("Loading Whisper model...")
whisper_model = whisper.load_model("base")
print("Whisper ready")

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".txt", ".pdf"}

# MARK: - Document Analysis Prompt
ANALYSIS_PROMPT = """You are an expert scientific communicator and data visualization specialist. Your job is to analyze extracted document text and transform it into the clearest, most accessible representation possible.

## Your Task
Analyze the provided text and:
1. Deeply understand the content, context, and core message
2. Identify the OPTIMAL output format based on the content type
3. Produce a high-quality, accurate output in that format

## Output Format Selection Rules

Choose EXACTLY ONE format based on these criteria:

**"text"** — Use when content is:
- Conceptual explanations, theories, or definitions
- Narratives, arguments, or opinions  
- Mixed content that doesn't fit other categories
- Any content where prose best preserves meaning

**"chart"** — Use when content contains:
- Numerical comparisons between categories
- Trends over time with specific data points
- Percentages, statistics, or quantitative rankings
- Data that would be clearer visually than in prose

**"table"** — Use when content involves:
- Direct comparisons of multiple items across consistent attributes
- Structured information with clear rows and columns
- Feature comparisons, specifications, or criteria evaluations

**"flowchart"** — Use when content describes:
- Sequential processes or workflows
- Step-by-step instructions or procedures
- Decision trees or cause-and-effect chains
- How something works mechanically or conceptually

## Output Format

Return ONLY a valid JSON object. No preamble, no explanation, no markdown fences.

For TEXT output:
{
  "output_type": "text",
  "summary": "Write 2-3 clear, engaging sentences that capture the essential meaning. Use precise but accessible language. Avoid jargon unless essential, and if used, briefly clarify it. Write as if explaining to a highly intelligent person who is unfamiliar with this specific domain."
}

For CHART output:
{
  "output_type": "chart",
  "summary": "One crisp sentence describing what this data reveals and why it matters.",
  "chart_type": "bar",
  "title": "Descriptive, informative chart title",
  "labels": ["Category A", "Category B", "Category C"],
  "values": [42, 78, 35],
  "x_label": "Meaningful x-axis label",
  "y_label": "Meaningful y-axis label with units"
}

For TABLE output:
{
  "output_type": "table",
  "summary": "One crisp sentence describing what this table compares and the key takeaway.",
  "title": "Descriptive table title",
  "headers": ["Item", "Attribute 1", "Attribute 2"],
  "rows": [["Row 1", "Value", "Value"], ["Row 2", "Value", "Value"]]
}

For FLOWCHART output:
{
  "output_type": "flowchart",
  "summary": "One crisp sentence describing what process or sequence this illustrates.",
  "title": "Descriptive process title",
  "steps": [
    "Step 1: Clear, concise description of first action or stage",
    "Step 2: Clear, concise description of second action or stage",
    "Step 3: Clear, concise description of third action or stage"
  ]
}

## Quality Standards
- Summaries must be genuinely informative, not vague or generic
- Chart labels must be meaningful, not placeholder text
- Table rows must contain real extracted data, not fabricated examples
- Flowchart steps must reflect the actual sequence described in the text
- All numbers in charts must come directly from the source text"""


# MARK: - Audio Summarization Prompt
AUDIO_PROMPT = """You are an expert meeting facilitator, note-taker, and communicator. Your job is to transform spoken transcripts into clear, structured, actionable summaries.

## Your Task
Analyze the provided transcript and produce a high-quality summary that captures:
- The core topic and purpose of the spoken content
- All key points, insights, and arguments made
- Any decisions reached or conclusions drawn
- Action items, next steps, or follow-ups mentioned
- Important questions raised (even if unanswered)

## Writing Guidelines
- Write in clear, professional prose
- Use paragraph breaks to organize different themes or sections
- Preserve the speaker's intent accurately — do not editorialize
- If the content is a lecture or explanation, summarize the knowledge conveyed
- If the content is a meeting or discussion, capture the outcomes and action items
- If the content is a voice note or personal memo, extract the key information
- Be concise but complete — every sentence should add value

## Output Format
Return ONLY a valid JSON object. No preamble, no explanation, no markdown fences.

{
  "output_type": "text",
  "summary": "Your complete, well-structured summary here. Use multiple sentences and paragraph breaks as needed. This should be genuinely useful to someone who was not present."
}"""


def parse_response(raw):
    try:
        raw = re.sub(r"```json|```", "", raw).strip()
        return json.loads(raw)
    except Exception as e:
        print("JSON parse error:", e)
        print("RAW:", raw[:500])
        return None


def cleanup_folders():
    for folder in [UPLOAD_FOLDER, OUTPUT_FOLDER]:
        for filename in os.listdir(folder):
            filepath = os.path.join(folder, filename)
            try:
                if os.path.isfile(filepath):
                    os.remove(filepath)
            except Exception as e:
                print(f"⚠️ Could not delete {filepath}: {e}")
    print("🧹 Cleaned up")


def extract_text(filepath):
    ext = os.path.splitext(filepath)[1].lower()

    if ext in [".jpg", ".jpeg", ".png"]:
        image = Image.open(filepath)
        if image.mode != "RGB":
            image = image.convert("RGB")
        text = pytesseract.image_to_string(image, config="--psm 6")
        return text.strip()

    elif ext == ".txt":
        with open(filepath, "r", encoding="utf-8") as f:
            return f.read()

    elif ext == ".pdf":
        from pdf_parser import extract_text_from_pdf
        return extract_text_from_pdf(filepath)

    raise ValueError(f"Unsupported file type: {ext}")


def analyze_with_groq(text):
    response = groq_client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[
            {"role": "system", "content": ANALYSIS_PROMPT},
            {"role": "user", "content": f"Analyze this document text and return the optimal structured output:\n\n{text[:4000]}"}
        ],
        temperature=0.2,
        max_tokens=1500
    )
    return response.choices[0].message.content.strip()


def summarize_audio_with_groq(transcript):
    response = groq_client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[
            {"role": "system", "content": AUDIO_PROMPT},
            {"role": "user", "content": f"Summarize this transcript:\n\n{transcript[:6000]}"}
        ],
        temperature=0.2,
        max_tokens=1500
    )
    return response.choices[0].message.content.strip()


@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "server running"}), 200


@app.route("/upload", methods=["POST"])
@app.route("/upload-image", methods=["POST"])
def upload():
    if "document" not in request.files:
        return jsonify({"error": "No file received"}), 400

    file = request.files["document"]
    if not file.filename:
        return jsonify({"error": "Empty filename"}), 400

    ext = os.path.splitext(file.filename)[1].lower() or ".jpg"
    if ext not in ALLOWED_EXTENSIONS:
        return jsonify({"error": f"Unsupported file type: {ext}"}), 400

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"upload_{timestamp}{ext}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)

    try:
        file.save(filepath)
        print(f"Received: {filename}")

        print("Extracting text...")
        text = extract_text(filepath)

        if not text.strip():
            cleanup_folders()
            return jsonify({"error": "No readable text found in image"}), 400

        print(f"Extracted {len(text)} chars")

        print("Analyzing with Groq...")
        raw = analyze_with_groq(text)
        print(f"Response preview: {raw[:200]}")

        parsed = parse_response(raw)
        if not parsed:
            cleanup_folders()
            return jsonify({"error": "Could not parse AI response"}), 500

        output_type = parsed.get("output_type", "text")
        summary = parsed.get("summary", "")
        print(f"Output type: {output_type}")

        visual_b64 = None
        if output_type != "text":
            try:
                from multimodal import generate_output
                visual_b64 = generate_output(output_type, parsed)
                if visual_b64:
                    print(f"Generated {output_type} visual")
            except Exception as e:
                print(f"⚠️ Visual generation failed: {e}")

        cleanup_folders()

        response_data = {
            "success": True,
            "output_type": output_type,
            "summary": summary,
            "result": summary
        }
        if visual_b64:
            response_data["image"] = visual_b64

        return jsonify(response_data), 200

    except Exception as e:
        cleanup_folders()
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/upload-text", methods=["POST"])
def upload_text():
    data = request.get_json()
    if not data or "text" not in data:
        return jsonify({"error": "No text received"}), 400

    try:
        raw = analyze_with_groq(data["text"])
        parsed = parse_response(raw)

        if not parsed:
            return jsonify({"error": "Could not parse response"}), 500

        output_type = parsed.get("output_type", "text")
        summary = parsed.get("summary", "")

        visual_b64 = None
        if output_type != "text":
            try:
                from multimodal import generate_output
                visual_b64 = generate_output(output_type, parsed)
            except Exception as e:
                print(f"⚠️ Visual generation failed: {e}")

        response_data = {
            "success": True,
            "output_type": output_type,
            "summary": summary,
            "result": summary
        }
        if visual_b64:
            response_data["image"] = visual_b64

        return jsonify(response_data), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/upload-audio", methods=["POST"])
def upload_audio():
    if "audio" not in request.files:
        return jsonify({"error": "No audio received"}), 400

    file = request.files["audio"]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"audio_{timestamp}.m4a"
    filepath = os.path.join(UPLOAD_FOLDER, filename)

    try:
        file.save(filepath)
        print(f"Audio received: {filename}")

        print("Transcribing with Whisper...")
        result = whisper_model.transcribe(filepath)
        transcript = result["text"].strip()
        print(f"Transcript ({len(transcript)} chars): {transcript[:200]}")

        if not transcript:
            cleanup_folders()
            return jsonify({"error": "Could not transcribe audio — try speaking more clearly"}), 400

        print("Summarizing with Groq...")
        raw = summarize_audio_with_groq(transcript)
        parsed = parse_response(raw)

        if not parsed:
            cleanup_folders()
            return jsonify({"error": "Could not parse summary"}), 500

        summary = parsed.get("summary", "")
        cleanup_folders()

        return jsonify({
            "success": True,
            "output_type": "text",
            "summary": summary,
            "result": summary,
            "transcript": transcript
        }), 200

    except Exception as e:
        cleanup_folders()
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000, debug=True)