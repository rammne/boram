extends Node

# Payload includes the word to type, time limit, and what happens next
signal start_typing_event(prompt_data: Variant, time_limit: float, event_type: String, zone_id: int)
signal typing_event_resolved(completed_words: int, total_words: int, event_type: String, zone_id: int)
signal typing_mistake
