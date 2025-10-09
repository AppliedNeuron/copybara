# Core Logic Implementation for `getLabels()` in Copybara

## 🎯 **Core Implementation Files**

The core logic for `getLabels()` is implemented across several key files:

### **1. LabelFinder.java** - Core Label Parsing Engine
**Location**: `java/com/google/copybara/LabelFinder.java`

**Purpose**: The heart of label parsing logic
```java
public class LabelFinder {
    private static final String VALID_LABEL_EXPR = "([\\w-]+)";
    private static final Pattern LABEL_PATTERN = Pattern.compile(
        "^" + VALID_LABEL_EXPR + "( *[:=] ?)(.*)");
    
    public boolean isLabel() {
        return matcher.matches() && !URL.matcher(line).matches();
    }
    
    public String getName() { return matcher.group(1); }
    public String getValue() { return matcher.group(3); }
}
```

### **2. ChangeMessage.java** - Message Parsing Coordinator
**Location**: `java/com/google/copybara/ChangeMessage.java`

**Purpose**: Orchestrates label parsing from commit messages
```java
public static ChangeMessage parseMessage(String message) {
    // Find label sections (after \n\n or \n--\n)
    // Parse each line as potential labels
}

private static List<LabelFinder> linesAsLabels(String message) {
    return Splitter.on('\n').splitToList(message).stream()
        .map(LabelFinder::new)
        .collect(Collectors.toList());
}

public ImmutableListMultimap<String, String> labelsAsMultimap() {
    ImmutableListMultimap.Builder<String, String> result = ImmutableListMultimap.builder();
    for (LabelFinder label : labels) {
        if (label.isLabel()) {
            result.put(label.getName(), label.getValue());
        }
    }
    return result.build();
}
```

### **3. ChangeReader.java** - Git Integration Layer
**Location**: `java/com/google/copybara/git/ChangeReader.java`

**Purpose**: Integrates label parsing with Git log output
```java
private ImmutableList<Change<GitRevision>> parseChanges(
    ImmutableList<GitLogEntry> logEntries,
    ImmutableMap<String, ImmutableListMultimap<String, String>> labels,
    GitRevision toRev) {
    
    for (GitLogEntry e : logEntries) {
        result.add(new Change<>(
            last.withUrl(url).withLabels(labelsToCopy),
            filterAuthor(e.author()),
            e.body() + branchCommitLog(last, e.parents()),
            e.authorDate(),
            ChangeMessage.parseAllAsLabels(e.body()).labelsAsMultimap(), // ← CORE LOGIC HERE
            e.files(),
            e.parents().size() > 1,
            e.parents()));
    }
}
```

### **4. Change.java** - Data Structure
**Location**: `java/com/google/copybara/revision/Change.java`

**Purpose**: Stores and provides access to labels
```java
public final class Change<R extends Revision> {
    private final ImmutableListMultimap<String, String> labels;
    
    public ImmutableListMultimap<String, String> getLabels() {
        return labels;
    }
}
```

## 🔄 **Core Logic Flow**

### **Step 1: Git Log Output**
```java
// GitRepository.java - Line 197
ChangeMessage.parseAllAsLabels(e.body()).labelsAsMultimap()
```

### **Step 2: Message Parsing**
```java
// ChangeMessage.java - Line 95
public static ChangeMessage parseAllAsLabels(String message) {
    return new ChangeMessage("", DOUBLE_NEWLINE, linesAsLabels(message));
}
```

### **Step 3: Line-by-Line Processing**
```java
// ChangeMessage.java - Line 100
private static List<LabelFinder> linesAsLabels(String message) {
    return Splitter.on('\n').splitToList(message).stream()
        .map(LabelFinder::new)  // ← Each line becomes a LabelFinder
        .collect(Collectors.toList());
}
```

### **Step 4: Label Detection**
```java
// LabelFinder.java - Line 108
public boolean isLabel() {
    return matcher.matches() && !URL.matcher(line).matches();
}
```

### **Step 5: Label Extraction**
```java
// ChangeMessage.java - Line 129
public ImmutableListMultimap<String, String> labelsAsMultimap() {
    ImmutableListMultimap.Builder<String, String> result = ImmutableListMultimap.builder();
    for (LabelFinder label : labels) {
        if (label.isLabel()) {
            result.put(label.getName(), label.getValue());  // ← Extract name/value
        }
    }
    return result.build();
}
```

## 🎯 **Key Implementation Details**

### **1. Regex Pattern Matching**
```java
// LabelFinder.java - Line 49
private static final String VALID_LABEL_EXPR = "([\\w-]+)";
private static final Pattern LABEL_PATTERN = Pattern.compile(
    "^" + VALID_LABEL_EXPR + "( *[:=] ?)(.*)");
```

**Pattern Breakdown**:
- `^` - Start of line
- `([\\w-]+)` - Label name (word characters + hyphens)
- `( *[:=] ?)` - Separator (colon or equals with optional spaces)
- `(.*)` - Label value (everything after separator)

### **2. Label Validation**
```java
// LabelFinder.java - Line 108
public boolean isLabel() {
    return matcher.matches() && !URL.matcher(line).matches();
}
```

**Validation Rules**:
- Must match the label pattern
- Must NOT look like a URL (`label://something`)

### **3. Multiple Label Handling**
```java
// ChangeMessage.java - Line 129
public ImmutableListMultimap<String, String> labelsAsMultimap() {
    // Uses ImmutableListMultimap to handle multiple values per key
    for (LabelFinder label : labels) {
        if (label.isLabel()) {
            result.put(label.getName(), label.getValue());
        }
    }
}
```

## 🚀 **Integration Points**

### **1. Git Origin Integration**
```java
// GitOrigin.java - Line 632
return new Change<>(ref, rev.getAuthor(), rev.getMessage(), rev.getDateTime(),
    rev.getLabels(), rev.getChangeFiles(), rev.isMerge(), rev.getParents())
    .withLabels(ref.associatedLabels());
```

### **2. Baseline Finding**
```java
// Origin.java - Line 369
ImmutableMap<String, Collection<String>> labels = input.getLabels().asMap();
if (labels.containsKey(label)) {
    baseline = new Baseline<>(Iterables.getLast(labels.get(label)),
        (R) input.getRevision());
}
```

### **3. Destination Status**
```java
// DestinationStatusVisitor.java - Line 56
if (change.getLabels().containsKey(labelName)) {
    String lastRev = Iterables.getLast(change.getLabels().get(labelName));
    destinationStatus = new DestinationStatus(lastRev, ImmutableList.of());
}
```

## 📋 **Summary**

The core logic for `getLabels()` is implemented in a layered architecture:

1. **LabelFinder.java** - Core regex-based label parsing
2. **ChangeMessage.java** - Message parsing and label extraction
3. **ChangeReader.java** - Git integration and change creation
4. **Change.java** - Data structure and access methods

The key insight is that **line 197 in ChangeReader.java** is where the magic happens:
```java
ChangeMessage.parseAllAsLabels(e.body()).labelsAsMultimap()
```

This single line orchestrates the entire label parsing process, from raw commit message to structured label data that can be used for baseline finding and migration tracking.


