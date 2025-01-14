"""
Python code evaluation module for Lux. Access via `:lux.eval`

This module provides functionality to evaluate Python code and convert Python values to Elixir terms.
Special handling is provided for converting Python dictionaries to Elixir structs when they contain
a '__class__' key.

Struct Conversion:
    Python dictionaries with a '__class__' key are converted to Elixir structs. For example:
    {'__class__': 'user', 'name': 'Alice'} -> %User{name: "Alice"}

    The conversion follows these rules:
    1. The '__class__' value is converted to PascalCase and prefixed with 'Elixir.'
    2. All dictionary keys are converted to atoms only if they are in the SAFE_ATOMS set
    3. The '__class__' key is removed from the final struct
    4. A '__struct__' key is added with the module name as an atom

    NOTE: This implementation does not verify that the target struct module exists in the Elixir
    system. It's the caller's responsibility to ensure that the struct modules are defined and
    available at runtime.

    SECURITY NOTE: To prevent atom table exhaustion, only predefined atoms in SAFE_ATOMS are allowed
    for struct field names. Attempting to use unsafe atoms will raise an UnsafeAtomError.

    Examples of class name conversion:
    - 'user' -> Elixir.User
    - 'data.types.point' -> Elixir.Data.Types.Point
"""
from erlport.erlterms import Atom
import ast
from .safe_atoms import safe_atom, safe_struct_keys, UnsafeAtomError

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
        if "__class__" in term:
            try:
                # Convert Python class name to Elixir module name format
                class_name = term["__class__"]
                module_parts = class_name.split('.')
                # Convert to PascalCase and join with dots
                module_name = '.'.join(p.capitalize() for p in module_parts)
                # Prefix with Elixir. for proper module name
                module_name = f"Elixir.{module_name}"
                
                # Create a new dict without the __class__ key
                struct_dict = term.copy()
                del struct_dict["__class__"]
                
                # Convert keys to atoms, will raise UnsafeAtomError if any key is unsafe
                encoded_dict = {
                    safe_atom(k): encode_term(v)
                    for k, v in struct_dict.items()
                }
                
                # Add the __struct__ field as an atom
                encoded_dict[safe_atom('__struct__')] = Atom(module_name.encode('utf-8'))
                return encoded_dict
            except UnsafeAtomError as e:
                return (Atom(b'error'), f"UnsafeAtomError: {str(e)}")
        else:
            # Regular dict - keep string keys
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

def is_expression(node):
    """Check if an AST node represents an expression that can be evaluated."""
    return isinstance(node, (ast.Expr, ast.Expression))

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

        # Parse the code into an AST
        tree = ast.parse(code, mode='exec')
        
        # If the code is empty, return None
        if not tree.body:
            return None
            
        # If we have multiple statements
        if len(tree.body) > 1:
            # Execute all but the last statement
            exec(ast.unparse(ast.Module(body=tree.body[:-1], type_ignores=[])), globals_dict)
            
        # Get the last statement
        last = tree.body[-1]
        
        # If the last statement is an expression, evaluate it
        if isinstance(last, ast.Expr):
            result = eval(ast.unparse(last.value), globals_dict)
            return encode_term(result)
        else:
            # Execute the last statement if it's not an expression
            exec(ast.unparse(ast.Module(body=[last], type_ignores=[])), globals_dict)
            return None
            
    except Exception as e:
        error_type = type(e).__name__
        error_msg = str(e)
        return (Atom(b'error'), f"{error_type}: {error_msg}") 