import os 
from supabase import create_client, Client 
from dotenv import load_dotenv 
 
load_dotenv() 
 
_client = None 
 
def get_supabase() -> Client: 
    global _client 
    if _client is None: 
        _client = create_client( 
            os.getenv("SUPABASE_URL"), 
            os.getenv("SUPABASE_KEY") 
        ) 
    return _client