from abc import ABC, abstractmethod
from erlport.erlterms import Atom
import uuid
import os
import re

class Prism(ABC):
    def __init__(self, **kwargs):
        if 'id' not in kwargs and hasattr(self, 'id'):
            kwargs['id'] = self.id
        if 'name' not in kwargs and hasattr(self, 'name'):
            kwargs['name'] = self.name
        if 'description' not in kwargs and hasattr(self, 'description'):
            kwargs['description'] = self.description
        if 'input_schema' not in kwargs and hasattr(self, 'input_schema'):
            kwargs['input_schema'] = self.input_schema
        if 'output_schema' not in kwargs and hasattr(self, 'output_schema'):
            kwargs['output_schema'] = self.output_schema

        if 'name' in kwargs:
            pattern = re.compile(r'^[A-Z][A-Za-z0-9]*(?:\.[A-Z][A-Za-z0-9]*)*$')
            if not pattern.match(kwargs['name']):
                raise ValueError("Name must follow namespace convention (e.g. 'Lux.Prisms.MyPrism')")

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
            'handler': (Atom(b'python'), os.path.abspath(__file__))
        }

    @abstractmethod
    def handler(self, input, context):
        pass

    @staticmethod
    @abstractmethod
    def new():
        pass