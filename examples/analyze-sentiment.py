#!/usr/bin/env python3
"""
Analyze sentiment of text or feedback using Azure OpenAI.

Usage:
    python analyze-sentiment.py "Your text to analyze"
    python analyze-sentiment.py --file feedback.txt

Environment Variables Required:
    AZURE_OPENAI_ENDPOINT - e.g., https://openai-ag-pssg-azure-files.openai.azure.com
    AZURE_OPENAI_KEY      - Your API key from Azure Portal
    AZURE_OPENAI_DEPLOYMENT - e.g., gpt-5-nano
"""

import os
import sys
import json
from openai import AzureOpenAI

def analyze_sentiment(client: AzureOpenAI, deployment: str, text: str) -> dict:
    """Analyze sentiment of given text."""
    
    prompt = f"""Analyze the sentiment of the following text and provide a structured response.

Text to analyze:
"{text}"

Respond in JSON format with:
{{
    "overall_sentiment": "positive" | "negative" | "neutral" | "mixed",
    "confidence": 0.0 to 1.0,
    "emotions_detected": ["list", "of", "emotions"],
    "key_phrases": ["important", "phrases"],
    "summary": "Brief 1-sentence summary of the sentiment"
}}

Only respond with valid JSON, no additional text.
"""
    
    response = client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": "You are a sentiment analysis assistant. Respond only with valid JSON."},
            {"role": "user", "content": prompt}
        ],
        max_completion_tokens=300,
        temperature=0.1  # Very low for consistent structured output
    )
    
    # Parse JSON response
    result_text = response.choices[0].message.content.strip()
    # Handle markdown code blocks if present
    if result_text.startswith("```"):
        result_text = result_text.split("```")[1]
        if result_text.startswith("json"):
            result_text = result_text[4:]
    
    return json.loads(result_text)

def main():
    # Parse arguments
    if len(sys.argv) < 2:
        print("Usage:")
        print('  python analyze-sentiment.py "Your text to analyze"')
        print('  python analyze-sentiment.py --file feedback.txt')
        sys.exit(1)
    
    # Get text to analyze
    if sys.argv[1] == "--file":
        if len(sys.argv) < 3:
            print("Error: Please provide a filename after --file")
            sys.exit(1)
        filepath = sys.argv[2]
        if not os.path.exists(filepath):
            print(f"Error: File not found: {filepath}")
            sys.exit(1)
        with open(filepath, 'r', encoding='utf-8') as f:
            text = f.read()
    else:
        text = " ".join(sys.argv[1:])
    
    # Check environment variables
    endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
    api_key = os.environ.get("AZURE_OPENAI_KEY")
    deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-5-nano")
    
    if not endpoint or not api_key:
        print("Error: Missing environment variables.")
        print("Please set:")
        print("  export AZURE_OPENAI_ENDPOINT='https://openai-ag-pssg-azure-files.openai.azure.com'")
        print("  export AZURE_OPENAI_KEY='<your-key>'")
        sys.exit(1)
    
    # Initialize client
    client = AzureOpenAI(
        azure_endpoint=endpoint,
        api_key=api_key,
        api_version="2024-12-01-preview"
    )
    
    print("Analyzing sentiment...")
    print("-" * 60)
    
    try:
        result = analyze_sentiment(client, deployment, text)
        
        # Pretty print results
        print("\n🎭 SENTIMENT ANALYSIS RESULTS\n")
        print(f"Overall Sentiment: {result['overall_sentiment'].upper()}")
        print(f"Confidence: {result['confidence']:.0%}")
        print(f"\nEmotions Detected: {', '.join(result['emotions_detected'])}")
        print(f"\nKey Phrases:")
        for phrase in result['key_phrases']:
            print(f"  • {phrase}")
        print(f"\nSummary: {result['summary']}")
        
    except json.JSONDecodeError as e:
        print(f"Error parsing response: {e}")
        print("Raw response may not be valid JSON")
    
    print("\n" + "-" * 60)
    print("✅ Analysis completed via private endpoint")

if __name__ == "__main__":
    main()
