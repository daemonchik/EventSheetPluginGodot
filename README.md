# EventSheet Plugin - Godot 4

![Demo Image](https://github.com/user-attachments/assets/3372e752-4e49-4e87-90f2-61b9b195eaff)

**EventSheet** is a visual event-driven programming system for Godot 4, similar to Construct 3's event system. It provides a user-friendly visual interface for creating game logic without writing code, making it easier for beginners and designers to create interactive experiences.

## Features

### ✅ Fully Functional Runtime System
- **Complete event execution** during gameplay
- **Visual event sheet editor** integrated into Godot's interface
- **Real-time event processing** with proper game loop integration

### 🎯 Supported Events
- **Start of Layout** - Triggers when the scene begins
- **Keyboard Input** - Key press/release detection
- **Mouse Input** - Click detection with button filtering
- **Collision Detection** - Automatic collision handling for Area2D nodes
- **Timer Events** - Time-based triggers with loop support

### ⚡ Available Actions
- **Object Management** - Create, destroy, position, and modify objects
- **Visual Properties** - Set visibility, scale, rotation, velocity
- **Audio Control** - Play/stop sounds with volume and loop options
- **Variable System** - Global variables with mathematical operations
- **Movement** - Angle-based movement and velocity control

### 🔧 Advanced Features
- **Expression Evaluation** - Support for variables, math operations, and string parsing
- **Condition System** - Compare values with multiple operators
- **Object Tagging** - Tag-based collision filtering
- **Timer Management** - Named timers with loop functionality
- **Comment System** - Documentation support in event sheets

The plugin facilitates the transition from Construct 3 to Godot 4 and opens new possibilities for 2D and 3D game development. Create complex game mechanics visually without programming knowledge.

The project is completely free and open source under the very free [MIT license](https://github.com/WladekProd/EventSheet/blob/main/LICENSE).
## FAQ

#### What is an Event Sheet:

Events consist of conditions that check if certain criteria are met, e.g. “Is the spacebar pressed?”. If all conditions are met, all actionsin the event occur, e.g. “Create bullet object”.
After all actions, there are sub-events that can check for other conditions, create more actions, more sub-events, and so on. Using this system, we can create complex functionality for our games and applications.

#### The “addons” folder:

- event_sheet - this is the main EventSheet plugin.
- plugin_refresher - (for developers) plugin allows to restart the main EventSheet plugin without restarting the project.
- explore-editor-theme - (for developers) plugin allows you to get standard icons and colors of Godot 4 Editor.

#### Folder “demo_project”:

- Stores the demo scene and the object to be created to test the execution of the visual code.

#### Folder “event_sheet”:

- Stores the last save of the Editor's event sheet.
## Authors

- [@wladekprod](https://github.com/WladekProd)
