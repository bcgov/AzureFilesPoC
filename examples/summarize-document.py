#!/usr/bin/env python3
"""
Summarize a document using Azure OpenAI via private endpoint.

Usage:
    python summarize-document.py <filename>
    python summarize-document.py sample-document.txt

Environment Variables Required:
    AZURE_OPENAI_ENDPOINT - e.g., https://openai-ag-pssg-azure-files.openai.azure.com
    AZURE_OPENAI_KEY      - Your API key from Azure Portal
    AZURE_OPENAI_DEPLOYMENT - e.g., gpt-5-nano
"""

import os
import sys
from openai import AzureOpenAI

def load_document(filepath: str) -> str:
    """Load document content from file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def summarize(client: AzureOpenAI, deployment: str, text: str) -> str:
    """Send text to Azure OpenAI for summarization."""
    
    prompt = f"""Please provide a concise summary of the following document. 
Include:
1. Main purpose/topic (1-2 sentences)
2. Key points (bullet list, max 5 items)
3. Action items or deadlines mentioned

Document:
{text}
"""
    
    response = client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": "You are a helpful assistant that summarizes government policy documents clearly and concisely."},
            {"role": "user", "content": prompt}
        ],
        max_completion_tokens=1000,
        reasoning_effort="low",  # Required for reasoning models like gpt-5-nano
        temperature=0.3  # Lower temperature for more focused summaries
    )
    
    return response.choices[0].message.content

def main():
    # Check arguments
    if len(sys.argv) < 2:
        print("Usage: python summarize-document.py <filename>")
        print("Example: python summarize-document.py sample-document.txt")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    # Check file exists
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    
    # Check environment variables
    endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
    api_key = os.environ.get("AZURE_OPENAI_KEY")
    deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-5-nano")
    
    if not endpoint or not api_key:
        print("Error: Missing environment variables.")
        print("Please set:")
        print("  export AZURE_OPENAI_ENDPOINT='https://openai-ag-pssg-azure-files.openai.azure.com'")
        print("  export AZURE_OPENAI_KEY='<your-key>'")
        print("  export AZURE_OPENAI_DEPLOYMENT='gpt-5-nano'  # optional")
        sys.exit(1)
    
    # Initialize client
    client = AzureOpenAI(
        azure_endpoint=endpoint,
        api_key=api_key,
        api_version="2024-12-01-preview"
    )
    
    # Load and summarize
    print(f"Loading document: {filepath}")
    document_text = load_document(filepath)
    print(f"Document length: {len(document_text)} characters")
    print("-" * 60)
    print("Sending to Azure OpenAI for summarization...")
    print("-" * 60)
    
    summary = summarize(client, deployment, document_text)
    
    print("\n📄 DOCUMENT SUMMARY\n")
    print(summary)
    print("\n" + "-" * 60)
    print("✅ Summary generated via private endpoint")

if __name__ == "__main__":
    main()
