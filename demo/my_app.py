import streamlit as st
import requests
import os

# Ollama endpoint from environment variable
OLLAMA_ENDPOINT = os.getenv(
    "OLLAMA_ENDPOINT", "http://localhost:80/backend/deepseek/generate"
)
# Model name from environment variable
MODEL_NAME = os.getenv("MODEL_NAME", "deepseek-r1")

st.title("Ollama Streamlit Integration")

st.write("Enter a question or topic, and I'll generate a response using Ollama.")

# Input text box for user prompt
user_input = st.text_input("Your question or topic:", "")

# Button to trigger the generation process
if st.button("Generate Response"):
    if user_input.strip():
        # Define the payload to send to Ollama
        payload = {
            "model": MODEL_NAME,
            "prompt": user_input,
            "stream": False,  # Set to True for continuous responses if needed
        }

        # Send the POST request to the Ollama endpoint
        response = requests.post(
            OLLAMA_ENDPOINT, json=payload, headers={"Content-Type": "application/json"}
        )

        if response.status_code == 200:
            # Get the text content from the response
            response_content = response.json().get("response", "No response received")
            st.write(f"**Response:** {response_content}")
        else:
            st.write(f"Error: {response.status_code}, {response.text}")
    else:
        st.write("Please enter a prompt.")
