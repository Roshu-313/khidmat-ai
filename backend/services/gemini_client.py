import vertexai
from vertexai.generative_models import GenerativeModel

vertexai.init(project="gen-lang-client-0765654837", location="us-central1")

def get_model():
    return GenerativeModel("gemini-2.5-flash")