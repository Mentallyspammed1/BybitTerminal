# indicators/base.py
from typing import Dict, Any

class Indicator:
    def __init__(self, config: Dict[str, Any]):
        """Initializes the indicator with a configuration."""
        self.config = config

    def calculate(self, data):
        """Calculates the indicator on the provided data."""
        raise NotImplementedError("Subclasses must implement the calculate method")

    def get_indicator_name(self) -> str:
        """Gets the name of the indicator."""
        raise NotImplementedError("Subclasses must implement get_indicator_name method")