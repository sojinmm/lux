from lux.prism import Prism

class SimplePrism(Prism):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def handler(self, input, context):
        return {
            'message': f'Hello, {input.get("name", "prism")}!',
        }


def create_prism():
    return SimplePrism(
        id='aaace2b1-8089-4d4e-b68e-2ce904da12f0',
        name='Simple Prism',
        description='A very simple prism',
        input_schema={
            'type': 'object',
            'properties': {
                'name': {
                    'type': 'string',
                    'description': 'The name of the person to greet'
                }
            },
            'required': ['name']
        },
        output_schema={
            'type': 'object',
            'properties': {
                'message': {
                    'type': 'string',
                    'description': 'The greeting message'
                }
            }
        }
    )
