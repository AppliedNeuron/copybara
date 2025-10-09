# Copybara Commit Search Logging

## Overview
This document explains the logging added to track how Copybara searches for commits and specifically how it searches for GitOrigin-RevID labels.

## How Copybara Searches for Commits and GitOrigin-RevID

### 1. Search Location
The main search happens in `GitDestination.getDestinationStatus()` method:
- **File**: `java/com/google/copybara/git/GitDestination.java`
- **Method**: `getDestinationStatus(Glob destinationFiles, String labelName)`
- **Lines**: 376-379

### 2. Search Mechanism
```java
ChangeReader.Builder changeReader =
    ChangeReader.Builder.forDestination(repo, baseConsole)
        .setFirstParent(lastRevFirstParent)
        .grep("^" + labelName + ORIGIN_LABEL_SEPARATOR);
```

- Uses `ChangeReader.Builder.forDestination()` with a grep pattern
- The `labelName` is typically "GitOrigin-RevId" 
- `ORIGIN_LABEL_SEPARATOR` is ": "
- This creates a grep pattern like `"^GitOrigin-RevId: "`

### 3. Commit Iteration Process
1. `GitVisitorUtil.visitChanges()` calls `ChangeReader.run()`
2. `ChangeReader.run()` calls `GitRepository.log()` with the grep pattern
3. `GitRepository.LogCmd.runGitLog()` executes the actual git log command

## Added Logging

### 1. Git Log Command Execution
**File**: `java/com/google/copybara/git/GitRepository.java`
**Method**: `runGitLog()`
**Lines**: 2682-2700

**Added logging**:
```java
// Log each commit that was searched for GitOrigin-RevID tracking
for (GitLogEntry entry : batchRes) {
  logger.atInfo().log("Searched commit: SHA=%s, Author=%s, Message=%s", 
      entry.commit().getSha1(), 
      entry.author().getName(), 
      entry.body().length() > 100 ? entry.body().substring(0, 100) + "..." : entry.body());
}
```

### 2. Destination Status Visitor
**File**: `java/com/google/copybara/DestinationStatusVisitor.java`
**Method**: `visit()`
**Lines**: 51-76

**Added logging**:
```java
logger.atInfo().log("Visiting commit: SHA=%s, Author=%s, Message=%s", 
    change.getRevision().getSha1(), 
    change.getAuthor().getName(), 
    change.getMessage().length() > 100 ? change.getMessage().substring(0, 100) + "..." : change.getMessage());

if (change.getLabels().containsKey(labelName)) {
  logger.atInfo().log("Found %s label in commit %s: %s", 
      labelName, change.getRevision().getSha1(), change.getLabels().get(labelName));
  // ... more detailed logging for found labels
} else {
  logger.atInfo().log("No %s label found in commit %s", labelName, change.getRevision().getSha1());
}
```

### 3. Search Start Logging
**File**: `java/com/google/copybara/git/GitDestination.java`
**Method**: `getDestinationStatus()`
**Lines**: 381-382

**Added logging**:
```java
logger.atInfo().log("Starting GitOrigin-RevID search from commit %s with grep pattern: ^%s%s", 
    startRef.getSha1(), labelName, ORIGIN_LABEL_SEPARATOR);
```

## Log Output Examples

When Copybara runs, you'll now see logs like:

```
INFO: Starting GitOrigin-RevID search from commit abc123def456 with grep pattern: ^GitOrigin-RevId: 
INFO: Executing: [log, --no-color, --format=...]
INFO: Log command returned 5 entries
INFO: Searched commit: SHA=abc123def456, Author=John Doe, Message=Initial commit
INFO: Searched commit: SHA=def456ghi789, Author=Jane Smith, Message=Add feature X
INFO: Searched commit: SHA=ghi789jkl012, Author=Bob Wilson, Message=Fix bug Y
INFO: Visiting commit: SHA=abc123def456, Author=John Doe, Message=Initial commit
INFO: No GitOrigin-RevId label found in commit abc123def456
INFO: Visiting commit: SHA=def456ghi789, Author=Jane Smith, Message=Add feature X
INFO: Found GitOrigin-RevId label in commit def456ghi789: [origin_commit_123]
INFO: GitOrigin-RevID found: origin_commit_123 in commit def456ghi789 for file src/main.java
```

## Benefits

1. **Visibility**: You can now see exactly which commits Copybara is searching through
2. **Debugging**: Easy to identify why a particular GitOrigin-RevID wasn't found
3. **Performance**: Can see how many commits are being processed
4. **Traceability**: Full audit trail of the search process

## Usage

To see these logs when running Copybara, ensure your logging level is set to INFO or lower:

```bash
# Example copybara command with verbose logging
copybara --log-level=INFO copy.bara.sky workflow_name
```

The logs will show:
- When the search starts and with what pattern
- Each git log command executed
- Each commit that gets searched
- Whether GitOrigin-RevID labels are found in each commit
- The final result when a matching commit is found


