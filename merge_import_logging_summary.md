# Merge Import Baseline Logging - Summary

## ✅ **Successfully Added Merge Import Logging**

I've added specific logging for merge import baseline finding in the `CHANGE_REQUEST` workflow mode. This will help you see exactly which commits are being searched when finding the baseline for merge import.

## 🔧 **What Was Added**

### **1. Merge Import Baseline Search Start**
```java
System.out.println(String.format("COPYBARA_MERGE_IMPORT: Starting baseline search for merge import from commit %s", 
    runHelper.getResolvedRef().asString()));
```

### **2. Baseline Search Results**
```java
if (baseline.isPresent()) {
  System.out.println(String.format("COPYBARA_MERGE_IMPORT: Found baseline: %s (origin revision: %s)", 
      baseline.get().getBaseline(), 
      baseline.get().getOriginRevision() != null ? baseline.get().getOriginRevision().asString() : "null"));
} else {
  System.out.println("COPYBARA_MERGE_IMPORT: No baseline found - will use fallback");
}
```

### **3. Merge Import Baseline Resolution**
```java
if (runHelper.workflowOptions().baselineForMergeImport == null) {
  if (baseline.isPresent()) {
    mergeImportBaseline = baseline.get().getOriginRevision();
    System.out.println(String.format("COPYBARA_MERGE_IMPORT: Using baseline origin revision for merge import: %s", 
        mergeImportBaseline != null ? mergeImportBaseline.asString() : "null"));
  } else {
    System.out.println("COPYBARA_MERGE_IMPORT: No baseline found, will throw validation exception");
    // ... throw exception
  }
} else {
  System.out.println(String.format("COPYBARA_MERGE_IMPORT: Using explicit baseline for merge import: %s", 
      runHelper.workflowOptions().baselineForMergeImport));
  mergeImportBaseline = runHelper.originResolveLastRev(runHelper.workflowOptions().baselineForMergeImport);
  System.out.println(String.format("COPYBARA_MERGE_IMPORT: Resolved merge import baseline to: %s", 
      mergeImportBaseline.asString()));
}
```

## 🚀 **How to Use**

### **Run Copybara with CHANGE_REQUEST mode (merge import)**
```bash
copybara copy.bara.sky workflow_name --mode=CHANGE_REQUEST
```

### **What You'll See**
The logs will now show detailed information about merge import baseline finding:

```
COPYBARA_CHANGE_REQUEST: Origin label name: GitOrigin-RevId
COPYBARA_MERGE_IMPORT: Starting baseline search for merge import from commit abc123def456
COPYBARA_START: Starting GitOrigin-RevID search from commit abc123def456 with grep pattern: ^GitOrigin-RevId: 
COPYBARA_SEARCH: Searched commit: SHA=abc123def456, Author=John Doe, Message=Current commit
COPYBARA_SEARCH: Searched commit: SHA=def456ghi789, Author=Jane Smith, Message=Previous commit
COPYBARA_VISIT: Visiting commit: SHA=abc123def456, Author=John Doe, Message=Current commit
COPYBARA_NO_LABEL: No GitOrigin-RevId label found in commit abc123def456
COPYBARA_VISIT: Visiting commit: SHA=def456ghi789, Author=Jane Smith, Message=Previous commit
COPYBARA_LABEL: Found GitOrigin-RevId label in commit def456ghi789: [origin_commit_123]
COPYBARA_FOUND: GitOrigin-RevID found: origin_commit_123 in commit def456ghi789 for file src/main.java
COPYBARA_MERGE_IMPORT: Found baseline: origin_commit_123 (origin revision: def456ghi789)
COPYBARA_MERGE_IMPORT: Using baseline origin revision for merge import: def456ghi789
```

## 🎯 **Key Benefits**

1. **Merge Import Visibility**: See exactly which commits are searched for merge import baseline
2. **Baseline Resolution**: Understand how the merge import baseline is determined
3. **Fallback Handling**: See when fallback mechanisms are used
4. **Explicit Baseline**: Track when explicit baseline is provided via `--baseline-for-merge-import`
5. **Full Traceability**: Complete audit trail of merge import baseline finding

## 🔍 **Log Types for Merge Import**

- **COPYBARA_CHANGE_REQUEST**: When CHANGE_REQUEST mode starts
- **COPYBARA_MERGE_IMPORT**: Merge import specific logging
  - **Starting baseline search**: When the search begins
  - **Found baseline**: When a baseline is found
  - **No baseline found**: When no baseline is found
  - **Using baseline origin revision**: When using found baseline
  - **Using explicit baseline**: When using `--baseline-for-merge-import`
  - **Resolved merge import baseline**: Final resolved baseline

## 📝 **Example Scenarios**

### **Scenario 1: Baseline Found**
```
COPYBARA_MERGE_IMPORT: Starting baseline search for merge import from commit abc123def456
COPYBARA_MERGE_IMPORT: Found baseline: origin_commit_123 (origin revision: def456ghi789)
COPYBARA_MERGE_IMPORT: Using baseline origin revision for merge import: def456ghi789
```

### **Scenario 2: No Baseline Found**
```
COPYBARA_MERGE_IMPORT: Starting baseline search for merge import from commit abc123def456
COPYBARA_MERGE_IMPORT: No baseline found - will use fallback
COPYBARA_MERGE_IMPORT: No baseline found, will throw validation exception
```

### **Scenario 3: Explicit Baseline**
```
COPYBARA_MERGE_IMPORT: Starting baseline search for merge import from commit abc123def456
COPYBARA_MERGE_IMPORT: Using explicit baseline for merge import: origin_commit_456
COPYBARA_MERGE_IMPORT: Resolved merge import baseline to: def456ghi789
```

## 🏗️ **Build Status**

✅ **Build Successful**: All compilation errors have been fixed and the project builds successfully.

## 📋 **Files Modified**

- **WorkflowMode.java** (lines 260-293): Added merge import baseline logging

The logging is now ready to help you understand exactly how Copybara finds the baseline for merge import operations!


