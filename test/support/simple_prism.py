from lux.prism import Prism

class SimplePrism(Prism):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def handle_signal(self, signal, context):
        return {
            'message': f'Hello, {signal.get("name", "prism")}!',
        }


def create_prism():
    return SimplePrism(id='aaace2b1-8089-4d4e-b68e-2ce904da12f0',
                       name='Simple Prism', description='A very simple prism')
