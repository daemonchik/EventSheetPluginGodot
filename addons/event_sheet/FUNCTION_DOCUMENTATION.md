# Event Sheet System - Function Documentation

This document provides comprehensive documentation for all functions in the Event Sheet system for Godot editor.

## Main Event Sheet Script (event_sheet.gd)

### Core Functions

#### `_ready() -> void`
Initializes the event sheet by loading saved data and adding the node to the "event_sheet" group.

#### `_shortcut_input(event: InputEvent) -> void`
Handles keyboard shortcuts for saving the event sheet when Ctrl+S or similar shortcuts are pressed.

#### `_input(event: InputEvent) -> void`
Processes mouse input events for double-clicking to add events and right-clicking to show context menus.

#### `save_event_sheet() -> void`
Saves the current event sheet data to a JSON file in the `res://event_sheet/` directory. Triggers filesystem scan for editor updates.

#### `load_event_sheet() -> void`
Loads event sheet data from the JSON file and reconstructs the event sheet structure with events, actions, and comments.

### Event Management Functions

#### `add_blank_body() -> Node`
Creates and returns a new blank body container for organizing events and actions.

#### `add_event(group_res: WGroup, event_res: WEvent, change_selected_body: bool, new_data: Dictionary, body = null) -> void`
Adds a new event to the event sheet. Can add to a specific body or create a new one if needed.

**Parameters:**
- `group_res`: The group resource containing the event
- `event_res`: The event resource to add
- `change_selected_body`: Whether to add to the currently selected body
- `new_data`: Dictionary of parameter data for the event
- `body`: Optional specific body to add the event to

#### `add_action(group_res: WGroup, action_res: WAction, change_selected_body: bool, new_data: Dictionary, body = null) -> void`
Adds a new action to the event sheet. Similar to `add_event` but for actions.

#### `delete_blank_body(blank_body) -> void`
Removes a blank body and clears all its associated events, actions, and comments.

#### `delete_event(blank_body, event) -> void`
Removes a specific event from a blank body.

#### `delete_action(blank_body, action) -> void`
Removes a specific action from a blank body.

### UI Management Functions

#### `show_popup_menu(menu: String = "general") -> void`
Displays a context menu based on the specified menu type (general, blank_body, event, action, comment).

#### `select_blank_body() -> void`
Updates the visual selection state of blank bodies to highlight the currently selected one.

#### `_on_mouse_entered() -> void`
Sets mouse focus when entering the event sheet area.

#### `_on_mouse_exited() -> void`
Clears mouse focus when leaving the event sheet area.

### Event Handlers

#### `_on_add_action_button_clicked(blank_body) -> void`
Handles clicks on the add action button within a blank body.

#### `_on_event_clicked(blank_body, event, index: int, button: int) -> void`
Handles mouse clicks on events (left-click for selection, right-click for context menu).

#### `_on_action_clicked(blank_body, action, index: int, button: int) -> void`
Handles mouse clicks on actions (left-click for selection, right-click for context menu).

#### `_on_comment_clicked(blank_body, comment, index: int, button: int) -> void`
Handles mouse clicks on comments (left-click for selection, right-click for context menu).

#### `_on_blank_body_clicked(blank_body, index: int, button: int) -> void`
Handles mouse clicks on blank bodies (left-click for selection, right-click for context menu).

#### `_on_popup_menu_index_pressed(index: int) -> void`
Processes context menu selections and executes corresponding actions.

### Window Management Functions

#### `show_add_window(type: String = "event", change_selected_body: bool = true) -> void`
Displays the window for adding new events or actions, loading available plugins.

#### `_on_add_window_close_requested() -> void`
Handles the close request for the add window.

#### `_on_add_event_or_action_close_requested() -> void`
Handles the close request for the event/action selection window.

#### `_on_set_parameter_close_requested() -> void`
Handles the close request for the parameter setting window.

### Parameter Management Functions

#### `edit_event(event) -> void`
Opens the parameter editing window for an existing event if it has configurable parameters.

#### `edit_action(action) -> void`
Opens the parameter editing window for an existing action if it has configurable parameters.

#### `toggle_event(event) -> void`
Toggles the enabled/disabled state of an event and saves the change.

#### `toggle_action(action) -> void`
Toggles the enabled/disabled state of an action and saves the change.

#### `show_edit_window(type: String, element) -> void`
Displays the parameter editing window for events or actions.

#### `_on_edit_finish_button_up(type: String, parameters_box: VBoxContainer, element) -> void`
Processes the completion of parameter editing and updates the element.

### Duplicate Functions

#### `duplicate_event(event) -> void`
Creates a copy of an existing event with the same parameters.

#### `duplicate_action(action) -> void`
Creates a copy of an existing action with the same parameters.

#### `duplicate_blank_body(blank_body) -> void`
Creates a complete copy of a blank body including all its events, actions, and comments.

### Comment Functions

#### `add_comment(blank_body) -> void`
Adds a new comment to a blank body.

#### `edit_comment(comment) -> void`
Focuses the text edit field of a comment for editing.

#### `delete_comment(blank_body, comment) -> void`
Removes a comment from a blank body.

#### `add_comment_with_text(blank_body, text: String) -> void`
Adds a comment with predefined text content (used during loading).

## Event Element Script (event.gd)

### Core Functions

#### `_ready() -> void`
Initializes the event element by setting up visual components and updating the display.

#### `_on_gui_input(event: InputEvent) -> void`
Handles mouse input for event interaction (left-click for selection, right-click for context menu).

#### `_on_h_split_container_dragged(offset: int) -> void`
Synchronizes the horizontal split offset across all event elements in the "event_split" group.

#### `get_save_data() -> Dictionary`
Returns the save data for this event element.

#### `update_visual() -> void`
Updates the visual appearance of the event element, including enabled/disabled state indicators and parameter display.

## Action Element Script (action.gd)

### Core Functions

#### `_ready() -> void`
Initializes the action element by setting up visual components and updating the display.

#### `_on_gui_input(event: InputEvent) -> void`
Handles mouse input for action interaction (left-click for selection, right-click for context menu).

#### `_on_h_split_container_dragged(offset: int) -> void`
Synchronizes the horizontal split offset across all action elements in the "action_split" group.

#### `get_save_data() -> Dictionary`
Returns the save data for this action element.

#### `update_visual() -> void`
Updates the visual appearance of the action element, including enabled/disabled state indicators and parameter display.

## Comment Element Script (comment.gd)

### Core Functions

#### `_ready() -> void`
Initializes the comment element and sets up the text content.

#### `_on_gui_input(event: InputEvent) -> void`
Handles mouse input for comment interaction (left-click for selection, right-click for context menu).

#### `_on_text_edit_text_changed() -> void`
Updates the comment data when the text content changes.

#### `get_save_data() -> Dictionary`
Returns the save data for this comment element.

#### `update_visual() -> void`
Updates the visual display of the comment when not being edited.

## Blank Body Container Script (blank_body.gd)

### Core Functions

#### `_ready() -> void`
Initializes the blank body container and stores initial size information.

#### `_process(delta: float) -> void`
Continuously monitors and updates the container size to maintain proper layout.

#### `set_selected(selected: bool) -> void`
Controls the visibility of the selection indicator panel.

#### `_on_add_action_button_up() -> void`
Emits signal when the add action button is clicked.

#### `_on_panel_gui_input(event: InputEvent) -> void`
Handles mouse input on the blank body panel for selection and context menus.

#### `_on_h_split_container_dragged(offset: int) -> void`
Synchronizes the horizontal split offset across all blank body elements in the "blank_body_split" group.

#### `_save() -> Dictionary`
Returns the complete save data for this blank body including all events, actions, and comments.

## Signal Descriptions

### Event Sheet Signals
- `add_action_button(blank_body)`: Emitted when the add action button is clicked
- `bb_popup_button(blank_body, index: int, button: int)`: Emitted for blank body mouse interactions

### Event Element Signals
- `event_clicked(blank_body, event, index: int, button: int)`: Emitted for event mouse interactions

### Action Element Signals
- `action_clicked(blank_body, action, index: int, button: int)`: Emitted for action mouse interactions

### Comment Element Signals
- `comment_clicked(blank_body, comment, index: int, button: int)`: Emitted for comment mouse interactions

## Data Structures

### Event Sheet Data Format
```json
{
  "0": {
    "events": {
      "0": {
        "group_resource_path": "res://addons/event_sheet/plugins/groups/system.tres",
        "resource_path": "res://addons/event_sheet/plugins/events/on_start_of_layout.tres",
        "new_parametrs": {}
      }
    },
    "actions": {
      "0": {
        "group_resource_path": "res://addons/event_sheet/plugins/groups/system.tres",
        "resource_path": "res://addons/event_sheet/plugins/actions/set_position.tres",
        "new_parametrs": {
          "x": "100",
          "y": "200"
        }
      }
    },
    "comments": {
      "0": {
        "text": "This is a comment"
      }
    }
  }
}
```

## Plugin System Integration

The Event Sheet system integrates with Godot's resource system to load event, action, and group plugins from the `res://addons/event_sheet/plugins/` directory. Plugins are automatically discovered and loaded at runtime, allowing for extensibility without code changes.

### Plugin Types
- **Groups**: Organize events and actions into logical categories
- **Events**: Trigger conditions that start execution chains
- **Actions**: Perform operations when triggered by events
- **Conditions**: Additional logic for complex event triggering

This documentation covers all functions and their purposes within the Event Sheet system, providing a complete reference for developers working with or extending the system.
