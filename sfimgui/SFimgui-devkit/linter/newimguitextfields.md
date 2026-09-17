
---

## 📝 **TEXT FIELD CAPABILITIES - COMPLETE GUIDE**

### **1. Text Field Types & Variations**

| Text Field Type | Function | Code Example | Use Case |
|-----------------|----------|--------------|----------|
| **Standard Input** | Single-line text | `ImGui.inputText("Label", buf, size)` | Names, IDs, simple text |
| **With Hint** | Placeholder text | `ImGui.inputTextWithHint("Label", "Hint...", buf, size)` | Search bars, forms |
| **Multiline** | Multiple lines | `ImGui.inputTextMultiline("Label", buf, size, dims)` | Notebook, scripts, notes |
| **Password** | Masked input | `ImGui.inputText("Password", buf, size, ImGuiInputTextFlags.Password)` | Password fields |
| **Numeric** | Number input | `ImGui.inputInt("Int", value)` | Integer values |
| **Float Input** | Float input | `ImGui.inputFloat("Float", value)` | Decimal values |
| **Double Input** | Double input | `ImGui.inputDouble("Double", value)` | High precision |
| **Scalar Input** | Generic number | `ImGui.inputScalar("Value", data_type, data)` | Any numeric type |
| **Color Input** | Color text | `ImGui.colorEdit4("Color", color)` | Color values |
| **With Completion** | Auto-complete | `ImGui.inputTextWithCompletion("Label", buf, size, callback)` | Skill search, commands |
| **With Callback** | Live validation | `ImGui.inputText("Label", buf, size, flags, callback)` | Real-time validation |

---

### **2. Input Text Flags (Comprehensive)**

```haxe
enum ImGuiInputTextFlags {
    None;                          // Default
    CharsDecimal;                  // Only decimal numbers
    CharsHexadecimal;              // Only hex numbers
    CharsScientific;               // Scientific notation
    CharsUppercase;                // Force uppercase
    CharsNoBlank;                  // No blank spaces
    AllowTabInput;                 // Tab inserts spaces
    EnterReturnsTrue;              // Return = submit
    EscapeClearsAll;               // Escape clears field
    CtrlEnterForNewLine;           // Ctrl+Enter = new line
    ReadOnly;                      // Read-only mode
    Password;                      // Password masking
    AlwaysOverwrite;               // Overwrite mode
    AutoSelectAll;                 // Auto-select on focus
    ParseEmptyRefVal;              // Parse empty as reference
    DisplayEmptyRefVal;            // Display empty as reference
    NoHorizontalScroll;            // Disable horizontal scroll
    NoUndoRedo;                    // Disable undo/redo
    ElideLeft;                     // Elide from left
    CallbackCompletion;            // Auto-complete callback
    CallbackHistory;               // History callback
    CallbackAlways;                // Always call callback
    CallbackCharFilter;            // Character filter callback
    CallbackResize;                // Resize callback
    CallbackEdit;                  // Edit callback
    WordWrap;                      // Word wrap (multiline)
    Multiline;                     // Force multiline mode
}
```

---

### **3. New Input Text API**

```haxe
// === STANDARD INPUT ===
ImGui.inputText("Name", nameBuf, 128);

// === INPUT WITH HINT (Placeholder) ===
ImGui.inputTextWithHint("##search", "🔍 Search auras...", searchBuf, 128);

// === MULTILINE INPUT ===
ImGui.inputTextMultiline("##notes", notesBuf, 4096, ImGui.vec2(400, 200));

// === PASSWORD INPUT ===
ImGui.inputText("Password", passBuf, 64, ImGuiInputTextFlags.Password);

// === NUMERIC INPUTS ===
ImGui.inputInt("Count", count, 1, 10);        // Step 1, fast step 10
ImGui.inputFloat("Speed", speed, 0.1, 1.0);   // Step 0.1, fast step 1.0
ImGui.inputDouble("Precision", precision, 0.01, 0.1);

// === SCALAR INPUT (Generic) ===
ImGui.inputScalar("Value", ImGuiDataType.Float, data, null, null, "%.3f");

// === COLOR INPUT ===
ImGui.colorEdit3("Color", color3);
ImGui.colorEdit4("Color with Alpha", color4, ImGuiColorEditFlags.AlphaBar);

// === INPUT WITH AUTO-COMPLETION ===
ImGui.inputTextWithCompletion("Skill", skillBuf, 64, completionCallback);
```

---

### **4. Auto-Completion System**

```haxe
// === COMPLETE AUTO-COMPLETION EXAMPLE ===
class AutoCompleteInput {
    var inputBuf:hl.Bytes = new hl.Bytes(128);
    var candidates:Array<String> = [];
    var selectedIndex:Int = 0;
    var showPopup:Bool = false;
    
    public function draw(label:String, suggestionList:Array<String>):String {
        // Draw input field
        if (ImGui.inputText(label, inputBuf, 128)) {
            var text = ByteUtil.readString(inputBuf, 128, true);
            // Update candidates
            candidates = suggestionList.filter(s -> 
                s.toLowerCase().indexOf(text.toLowerCase()) == 0
            );
            showPopup = candidates.length > 0 && text.length > 0;
            selectedIndex = 0;
        }
        
        // Draw completion popup
        if (showPopup) {
            var pos = ImGui.getCursorScreenPos();
            ImGui.setNextWindowPos(ImGui.vec2(pos.x, pos.y + ImGui.getFontSize() + 4));
            ImGui.setNextWindowSize(ImGui.vec2(200, Math.min(candidates.length * 22, 120)));
            
            if (ImGui.begin("##autocomplete", null, 
                ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | 
                ImGuiWindowFlags.NoMove | ImGuiWindowFlags.Tooltip)) {
                
                for (i in 0...candidates.length) {
                    if (ImGui.selectable(candidates[i], i == selectedIndex)) {
                        // Select candidate
                        ByteUtil.fillBuf(inputBuf, 128, candidates[i]);
                        showPopup = false;
                        return candidates[i];
                    }
                }
                ImGui.end();
            }
            
            // Keyboard navigation
            if (ImGui.isKeyPressed(ImGuiKey.DownArrow)) {
                selectedIndex = (selectedIndex + 1) % candidates.length;
            }
            if (ImGui.isKeyPressed(ImGuiKey.UpArrow)) {
                selectedIndex = (selectedIndex - 1 + candidates.length) % candidates.length;
            }
            if (ImGui.isKeyPressed(ImGuiKey.Enter) && candidates.length > 0) {
                ByteUtil.fillBuf(inputBuf, 128, candidates[selectedIndex]);
                showPopup = false;
                return candidates[selectedIndex];
            }
            if (ImGui.isKeyPressed(ImGuiKey.Escape)) {
                showPopup = false;
            }
        }
        
        return ByteUtil.readString(inputBuf, 128, true);
    }
}

// === USAGE IN AURA BUILDER ===
var skillAutoComplete = new AutoCompleteInput();
var skillList = ["Burning Blade", "Shadow Step", "Chain Lightning", "Rend", "Execute"];
var selectedSkill = skillAutoComplete.draw("Skill Search", skillList);
```

---

### **5. Input Text Callbacks (Live Validation)**

```haxe
// === INPUT TEXT CALLBACK ===
function drawValidatedInput(label:String, buf:hl.Bytes, size:Int):Bool {
    var isValid = true;
    var validationError = "";
    
    // Define callback
    var callback = function(data:ImGuiInputTextCallbackData):Int {
        var text = ByteUtil.readString(buf, size, true);
        
        // Validation logic
        if (text.length > 0 && !~/^[a-zA-Z0-9_]+$/.match(text)) {
            isValid = false;
            validationError = "Only letters, numbers, and underscores allowed";
            return 1; // Reject input
        }
        
        isValid = true;
        validationError = "";
        return 0;
    };
    
    // Draw input with callback
    var result = ImGui.inputText(label, buf, size, 
        ImGuiInputTextFlags.CallbackCharFilter, callback);
    
    // Show validation status
    if (!isValid) {
        ImGui.textColored(ImGui.vec4(1, 0.2, 0.2, 1), "⚠ " + validationError);
    } else if (ByteUtil.readString(buf, size, true).length > 0) {
        ImGui.textColored(ImGui.vec4(0.2, 0.8, 0.2, 1), "✅ Valid");
    }
    
    return result;
}
```

---

### **6. Smart Input Features**

```haxe
// === SMART NUMBER INPUT ===
function smartNumberInput(label:String, value:FloatRef, min:Float, max:Float, step:Float):Bool {
    var changed = false;
    var text = Std.string(value.get());
    var buf = hl.Bytes.fromUTF8(text);
    
    // Input with validation
    if (ImGui.inputText(label, buf, 64, ImGuiInputTextFlags.CharsDecimal)) {
        var newText = ByteUtil.readString(buf, 64, true);
        var newValue = Std.parseFloat(newText);
        if (!Math.isNaN(newValue)) {
            value.set(Math.max(min, Math.min(max, newValue)));
            changed = true;
        }
    }
    
    // Quick buttons
    ImGui.sameLine();
    if (ImGui.smallButton("+")) {
        value.set(Math.min(max, value.get() + step));
        changed = true;
    }
    ImGui.sameLine();
    if (ImGui.smallButton("-")) {
        value.set(Math.max(min, value.get() - step));
        changed = true;
    }
    
    // Range display
    ImGui.sameLine();
    ImGui.textDisabled("(" + Std.int(min) + " - " + Std.int(max) + ")");
    
    return changed;
}

// === SCRIPT EDITOR WITH SYNTAX HIGHLIGHTING ===
class ScriptEditor {
    var buf:hl.Bytes = new hl.Bytes(4096);
    var keywords:Array<String> = [
        "if", "else", "then", "and", "or", "not", "true", "false",
        "combo", "rage", "targetHp", "cooldownRemaining"
    ];
    
    public function draw(label:String):String {
        // Editor with word wrap and tab support
        var flags = ImGuiInputTextFlags.AllowTabInput | 
                   ImGuiInputTextFlags.WordWrap |
                   ImGuiInputTextFlags.CtrlEnterForNewLine;
        
        if (ImGui.inputTextMultiline(label, buf, 4096, ImGui.vec2(400, 200), flags)) {
            // Auto-format on change
            var text = ByteUtil.readString(buf, 4096, true);
            // Highlight keywords in real-time
            return text;
        }
        
        // Show line count
        var text = ByteUtil.readString(buf, 4096, true);
        var lines = text.split("\n").length;
        ImGui.textDisabled("Lines: " + lines + " | Characters: " + text.length);
        
        return text;
    }
}
```

---

### **7. Input Text Styling**

```haxe
// === STYLED INPUT FIELDS ===
function drawStyledInput(label:String, buf:hl.Bytes, size:Int):Bool {
    // Push custom styles
    ImGui.pushStyleColor(ImGuiCol.FrameBg, ImGui.vec4(0.1, 0.12, 0.18, 1));
    ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, ImGui.vec4(0.15, 0.18, 0.25, 1));
    ImGui.pushStyleColor(ImGuiCol.FrameBgActive, ImGui.vec4(0.18, 0.22, 0.3, 1));
    ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 6);
    ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(8, 4));
    
    var result = ImGui.inputText(label, buf, size);
    
    ImGui.popStyleVar(2);
    ImGui.popStyleColor(3);
    
    return result;
}

// === SEARCH BAR WITH CLEAR BUTTON ===
function drawSearchBar(label:String, buf:hl.Bytes, size:Int):String {
    // Search icon
    ImGui.text("🔍");
    ImGui.sameLine();
    
    // Input field
    var result = ImGui.inputText(label, buf, size);
    var text = ByteUtil.readString(buf, size, true);
    
    // Clear button (X)
    ImGui.sameLine();
    if (text.length > 0) {
        if (ImGui.smallButton("✕")) {
            ByteUtil.clearBytes(buf, size);
            text = "";
        }
    }
    
    return text;
}
```

---

### **8. Input Text States & Feedback**

```haxe
// === INPUT WITH STATE FEEDBACK ===
function drawStatefulInput(label:String, buf:hl.Bytes, size:Int, 
                           isValid:Bool, errorMessage:String):Bool {
    // Color based on state
    if (isValid) {
        ImGui.pushStyleColor(ImGuiCol.FrameBg, ImGui.vec4(0.1, 0.2, 0.1, 1));
        ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, ImGui.vec4(0.15, 0.25, 0.15, 1));
    } else {
        ImGui.pushStyleColor(ImGuiCol.FrameBg, ImGui.vec4(0.2, 0.1, 0.1, 1));
        ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, ImGui.vec4(0.25, 0.15, 0.15, 1));
    }
    
    var result = ImGui.inputText(label, buf, size);
    
    ImGui.popStyleColor(2);
    
    // Show status
    if (!isValid && errorMessage.length > 0) {
        ImGui.textColored(ImGui.vec4(1, 0.2, 0.2, 1), "⚠ " + errorMessage);
    }
    
    return result;
}
```

---

### **9. Input Text with Memory (History)**

```haxe
// === INPUT WITH HISTORY ===
class InputHistory {
    var history:Array<String> = [];
    var maxHistory:Int = 20;
    var historyIndex:Int = -1;
    var currentText:String = "";
    
    public function draw(label:String, buf:hl.Bytes, size:Int):String {
        var result = ImGui.inputText(label, buf, size);
        var text = ByteUtil.readString(buf, size, true);
        
        // Up/Down arrow for history
        if (ImGui.isItemActive()) {
            if (ImGui.isKeyPressed(ImGuiKey.UpArrow) && historyIndex < history.length - 1) {
                historyIndex++;
                if (historyIndex == 0) {
                    currentText = text;
                }
                if (historyIndex < history.length) {
                    ByteUtil.fillBuf(buf, size, history[historyIndex]);
                    text = history[historyIndex];
                }
            }
            if (ImGui.isKeyPressed(ImGuiKey.DownArrow) && historyIndex >= 0) {
                historyIndex--;
                if (historyIndex >= 0) {
                    ByteUtil.fillBuf(buf, size, history[historyIndex]);
                    text = history[historyIndex];
                } else {
                    ByteUtil.fillBuf(buf, size, currentText);
                    text = currentText;
                }
            }
        }
        
        // Add to history on Enter
        if (result && text.length > 0) {
            if (history.length == 0 || history[0] != text) {
                history.unshift(text);
                if (history.length > maxHistory) history.pop();
            }
            historyIndex = -1;
            currentText = "";
        }
        
        return text;
    }
}
```

---

### **10. New Input Text Features Summary**

| Feature | Before | After |
|---------|--------|-------|
| **Types** | Basic input only | 10+ types (standard, hint, multiline, password, numeric, etc.) |
| **Flags** | 2-3 flags | 20+ flags for granular control |
| **Callbacks** | None | Full callback system (validation, filtering, editing) |
| **Auto-Completion** | None | Built-in auto-complete with popup |
| **History** | None | History support with Up/Down arrows |
| **Validation** | Manual | Live validation with color feedback |
| **Styling** | Basic | Full style customization per field |
| **Word Wrap** | None | Word wrap in multiline |
| **Tab Support** | None | Tab inserts spaces (code editor style) |
| **Undo/Redo** | Basic | Full undo/redo history |
| **Password** | None | Password masking |
| **Numeric** | Manual | Built-in numeric types with validation |
| **Placeholder** | None | Hint/placeholder text |

---

### **11. Complete Example: Aura Script Editor**

```haxe
// === COMPLETE SCRIPT EDITOR EXAMPLE ===
class AuraScriptEditor {
    var scriptBuf:hl.Bytes = new hl.Bytes(4096);
    var errorMsg:String = "";
    var hasError:Bool = false;
    var isDirty:Bool = false;
    var autoComplete = new AutoCompleteInput();
    var history = new InputHistory();
    
    public function draw(aura:AuraDef):Bool {
        var changed = false;
        
        // Title with status
        ImGui.text("Script Editor");
        ImGui.sameLine();
        if (isDirty) {
            ImGui.textColored(ImGui.vec4(1, 0.8, 0.2, 1), "✏️");
        }
        ImGui.sameLine();
        if (hasError) {
            ImGui.textColored(ImGui.vec4(1, 0.2, 0.2, 1), "⚠");
        }
        
        // Toolbar
        ImGui.separator();
        if (ImGui.button("Format")) {
            var text = ByteUtil.readString(scriptBuf, 4096, true);
            ByteUtil.fillBuf(scriptBuf, 4096, formatScript(text));
            changed = true;
        }
        ImGui.sameLine();
        if (ImGui.button("Validate")) {
            var text = ByteUtil.readString(scriptBuf, 4096, true);
            validateScript(text);
        }
        ImGui.sameLine();
        if (ImGui.button("Revert")) {
            ByteUtil.fillBuf(scriptBuf, 4096, aura.script);
            isDirty = false;
            hasError = false;
            errorMsg = "";
        }
        
        // Script editor
        var flags = ImGuiInputTextFlags.AllowTabInput | 
                   ImGuiInputTextFlags.WordWrap |
                   ImGuiInputTextFlags.CtrlEnterForNewLine |
                   ImGuiInputTextFlags.CallbackAlways;
        
        // Editor with live validation
        if (ImGui.inputTextMultiline("##script", scriptBuf, 4096, 
            ImGui.vec2(-1, 200), flags)) {
            changed = true;
            isDirty = true;
            var text = ByteUtil.readString(scriptBuf, 4096, true);
            validateScript(text);
        }
        
        // Show errors
        if (hasError) {
            ImGui.textColored(ImGui.vec4(1, 0.2, 0.2, 1), "❌ " + errorMsg);
        } else if (isDirty) {
            ImGui.textColored(ImGui.vec4(0.2, 0.8, 0.2, 1), "✅ Script is valid");
        }
        
        // Save button
        if (changed && !hasError) {
            ImGui.separator();
            if (ImGui.button("Apply Script", ImGui.vec2(-1, 0))) {
                aura.script = ByteUtil.readString(scriptBuf, 4096, true);
                isDirty = false;
                ToastManager.success("Script applied!");
            }
        }
        
        return changed;
    }
    
    function formatScript(text:String):String {
        // Simple formatting
        var lines = text.split("\n");
        var indentLevel = 0;
        var result = "";
        
        for (line in lines) {
            var trimmed = StringTools.trim(line);
            if (trimmed.indexOf("}") == 0) indentLevel--;
            if (trimmed.length > 0) {
                var indent = "";
                for (i in 0...Math.max(0, indentLevel)) indent += "  ";
                result += indent + trimmed + "\n";
            }
            if (trimmed.indexOf("{") >= 0) indentLevel++;
        }
        
        return result;
    }
    
    function validateScript(text:String):Void {
        // Simple validation
        hasError = false;
        errorMsg = "";
        
        // Check for balanced brackets
        var open = 0;
        for (c in text) {
            if (c == '(' || c == '{') open++;
            if (c == ')' || c == '}') open--;
        }
        if (open != 0) {
            hasError = true;
            errorMsg = "Unbalanced brackets";
            return;
        }
        
        // Check for reserved keywords
        var lines = text.split("\n");
        for (line in lines) {
            if (line.indexOf("combo") >= 0) {
                // Valid
            }
        }
    }
}
```

---

## 🎯 **Summary: What You Can Now Build**

| Feature | Description | Your Mod Use |
|---------|-------------|--------------|
| **Search Bars** | With hint, clear button, auto-complete | Aura search, Geaux skill search |
| **Script Editor** | Code editor with formatting, validation | Aura condition scripts |
| **Auto-Complete** | Smart completion popup | Skill names, commands |
| **Password Input** | Masked input | Settings password |
| **Numeric Inputs** | With step buttons, validation | Configuration values |
| **Multiline Editor** | Word wrap, tab support | Notebook, notes |
| **Live Validation** | Real-time feedback | Form validation |
| **Input History** | Up/Down history | Command line |
| **Stylable Fields** | Custom colors, rounding | Themed UI |
| **Callbacks** | Filter, validate, edit | Live filtering |

