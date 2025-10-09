# How `getLabels()` Works in Copybara

## 🎯 **Overview**

The `getLabels()` function in Copybara extracts structured metadata (labels) from commit messages. It's a key component for tracking migration history and finding baselines.

## 🔧 **How It Works**

### **1. Data Structure**
```java
// Change object contains labels as a multimap
private final ImmutableListMultimap<String, String> labels;

// getLabels() returns this multimap
public ImmutableListMultimap<String, String> getLabels() {
    return labels;
}
```

### **2. Label Parsing Process**

#### **Step 1: Message Parsing**
```java
// In ChangeMessage.parseMessage()
public static ChangeMessage parseMessage(String message) {
    // Look for label sections in commit message
    // Labels are typically in the last paragraph after "\n\n" or "\n--\n"
}
```

#### **Step 2: Label Detection**
```java
// LabelFinder uses regex to detect labels
private static final Pattern LABEL_PATTERN = Pattern.compile(
    "^" + VALID_LABEL_EXPR + "( *[:=] ?)(.*)");
// VALID_LABEL_EXPR = "([\\w-]+)"  // word characters and hyphens
```

#### **Step 3: Label Format**
Labels follow this pattern:
```
LABEL_NAME : VALUE
LABEL_NAME = VALUE
```

**Examples:**
```
GitOrigin-RevId: abc123def456
Bug: 12345
Author: john.doe@example.com
```

### **3. Label Processing**

#### **In the Origin.findBaseline() method:**
```java
public VisitResult visit(Change<? extends Revision> input) {
    // Get all labels from the change
    ImmutableMap<String, Collection<String>> labels = input.getLabels().asMap();
    
    // Check if the specific label exists
    if (!labels.containsKey(label)) {
        return VisitResult.CONTINUE;  // Keep searching
    }
    
    // Found the label! Use the last value
    baseline = new Baseline<>(Iterables.getLast(labels.get(label)),
        (R) input.getRevision());
    return VisitResult.TERMINATE;  // Stop searching
}
```

## 📋 **Label Structure**

### **ImmutableListMultimap<String, String>**
- **Key**: Label name (e.g., "GitOrigin-RevId")
- **Value**: Label value (e.g., "abc123def456")
- **Multiple Values**: Same label can appear multiple times

### **Example:**
```java
// Commit message:
"""
Add new feature

GitOrigin-RevId: abc123def456
Bug: 12345
Bug: 67890
Author: john.doe@example.com
"""

// Results in:
labels = {
    "GitOrigin-RevId" -> ["abc123def456"],
    "Bug" -> ["12345", "67890"],
    "Author" -> ["john.doe@example.com"]
}
```

## 🔍 **Label Detection Rules**

### **1. Valid Label Names**
```java
VALID_LABEL_EXPR = "([\\w-]+)"
```
- **Word characters**: `[a-zA-Z0-9_]`
- **Hyphens**: `-`
- **Examples**: `GitOrigin-RevId`, `Bug`, `Author`, `PR-123`

### **2. Label Separators**
- **Colon**: `GitOrigin-RevId: abc123`
- **Equals**: `GitOrigin-RevId= abc123`
- **Spaces**: Optional spaces around separator

### **3. Label Location**
- **Last Paragraph**: Labels are typically in the last paragraph of commit messages
- **After `\n\n`**: Separated by double newline
- **After `\n--\n`**: Alternative separator

## 🚀 **Usage Examples**

### **1. Finding Baseline**
```java
// In Origin.findBaseline()
ImmutableMap<String, Collection<String>> labels = input.getLabels().asMap();
if (labels.containsKey("GitOrigin-RevId")) {
    // Found the label! Get the last value
    String originRevId = Iterables.getLast(labels.get("GitOrigin-RevId"));
    // Use this as baseline
}
```

### **2. Multiple Label Values**
```java
// If a label appears multiple times:
labels = {
    "Bug" -> ["12345", "67890", "99999"]
}

// Get the last occurrence:
String lastBug = Iterables.getLast(labels.get("Bug"));  // "99999"
```

### **3. Label Validation**
```java
// Check if a line is a valid label
LabelFinder finder = new LabelFinder("GitOrigin-RevId: abc123");
if (finder.isLabel()) {
    String name = finder.getName();      // "GitOrigin-RevId"
    String value = finder.getValue();   // "abc123"
}
```

## 🎯 **Key Methods**

### **Change.getLabels()**
```java
public ImmutableListMultimap<String, String> getLabels() {
    return labels;
}
```

### **Change.getLabels().asMap()**
```java
// Convert to Map<String, Collection<String>>
ImmutableMap<String, Collection<String>> labelsMap = change.getLabels().asMap();
```

### **LabelFinder.isLabel()**
```java
// Check if a line contains a valid label
LabelFinder finder = new LabelFinder("GitOrigin-RevId: abc123");
boolean isValid = finder.isLabel();  // true
```

## 🔄 **Label Processing Flow**

1. **Commit Message** → **ChangeMessage.parseMessage()**
2. **Extract Label Section** → **linesAsLabels()**
3. **Parse Each Line** → **LabelFinder constructor**
4. **Validate Labels** → **LabelFinder.isLabel()**
5. **Extract Name/Value** → **LabelFinder.getName()/getValue()**
6. **Build Multimap** → **labelsAsMultimap()**
7. **Store in Change** → **Change.labels field**

## 📝 **Common Label Types**

### **Copybara Standard Labels**
- **`GitOrigin-RevId`**: Original Git commit SHA
- **`Copybara-RevId`**: Copybara-generated revision ID
- **`Copybara-Change-Id`**: Gerrit-style change ID

### **Custom Labels**
- **`Bug`**: Bug tracking numbers
- **`Author`**: Author information
- **`PR`**: Pull request numbers
- **`Issue`**: Issue tracking numbers

## 🎯 **Summary**

The `getLabels()` function is a sophisticated system that:

1. **Parses commit messages** to extract structured metadata
2. **Uses regex patterns** to identify valid label formats
3. **Handles multiple values** for the same label
4. **Provides easy access** to label data via multimap
5. **Enables baseline finding** by searching for specific labels
6. **Supports custom labels** for various tracking needs

This system is crucial for Copybara's ability to track migration history and find the correct baseline for incremental migrations.


