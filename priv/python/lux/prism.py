from abc import ABC, abstractmethod
from erlport.erlterms import Atom
import uuid
import os

class Prism(ABC):
    def __init__(self, **kwargs):
        self.id = kwargs.get('id', str(uuid.uuid4()))
        self.name = kwargs.get('name', '')
        self.description = kwargs.get('description', '')
        self.input_schema = kwargs.get('input_schema', {})
        self.output_schema = kwargs.get('output_schema', {})
    
    def view(self):
        return {
            '__class__': self.__class__.__name__,
            '__struct__': Atom(b'Elixir.Lux.Prism'),
            'id': self.id,
            'name': self.name,
            'examples': '',
            'description': self.description,
            'input_schema': self.input_schema,
            'output_schema': self.output_schema,
            'handler': {
                'type': 'python',
                'path': os.path.abspath(__file__)
            }
        }

    @abstractmethod
    def handle_signal(self, signal, context):
        pass