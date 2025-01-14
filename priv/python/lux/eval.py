"""
Python code evaluation module for Lux. Access via `:lux.eval`
"""
from erlport.erlterms import Atom

def encode_term(term):
    """Convert Python types to Erlang terms."""
    if term is None:
        return Atom(b'nil')
    elif isinstance(term, str):
        return term.encode('utf-8')  # Convert strings to binary for proper Elixir string handling
    elif isinstance(term, (int, float, bool)):
        return term
    elif isinstance(term, (list, tuple)):
        return [encode_term(item) for item in term]
    elif isinstance(term, dict):
        return {encode_term(k): encode_term(v) for k, v in term.items()}
    return term

def decode_term(term):
    """Convert Erlang terms to Python types."""
    if isinstance(term, Atom):
        return term.name.decode('utf-8')
    elif isinstance(term, (list, tuple)):
        return [decode_term(item) for item in term]
    elif isinstance(term, dict):
        return {decode_term(k): decode_term(v) for k, v in term.items()}
    elif isinstance(term, bytes):
        return term.decode('utf-8')
    return term

def execute(code, variables=None):
    """Execute Python code with optional variable bindings."""
    try:
        # Handle string encoding from Erlang
        if isinstance(code, bytes):
            code = code.decode('utf-8')

        # Create a shared globals dictionary that includes builtins
        globals_dict = {'__builtins__': __builtins__}
        
        # Add variables to globals so they're accessible everywhere
        if variables:
            globals_dict.update({
                (k.decode('utf-8') if isinstance(k, bytes) else str(k)): decode_term(v) 
                for k, v in variables.items()
            })
        
        # Split the code into statements and the final expression
        lines = code.strip().split('\n')
        if not lines:
            return None
            
        # If we have multiple lines, execute all but the last as statements
        if len(lines) > 1:
            statements = '\n'.join(lines[:-1])
            exec(statements, globals_dict)
            
        # Execute the last line as an expression and return its value
        try:
            result = eval(lines[-1], globals_dict)
            return encode_term(result)
        except SyntaxError:
            exec(lines[-1], globals_dict)
            return None
    except Exception as e:
        error_type = type(e).__name__
        error_msg = str(e)
        return (Atom(b'error'), f"{error_type}: {error_msg}") 