# CHANGE_REQUEST Mode: Git History Preservation in Copybara

## 🎯 **Current Behavior: CHANGE_REQUEST Always Squashes**

Unfortunately, **CHANGE_REQUEST mode in Copybara always creates a single squashed commit** in the destination, regardless of how many individual commits are in your source change request (PR). Here's why:

### **📋 How CHANGE_REQUEST Processes Multiple Commits**

Looking at the code in `WorkflowMode.java` (lines 436-450):

```java
// CHANGE_REQUEST mode - always creates ONE commit
migrator.migrate(
    runHelper.getResolvedRef(),
    /*lastRev=*/ null,
    runHelper.getConsole(),
    // Use latest change as the message/author. If it contains multiple changes the user
    // can always use metadata.squash_notes or similar.
    new Metadata(
        runHelper.getChangeMessage(Iterables.getLast(changes).getMessage()),
        runHelper.getFinalAuthor(Iterables.getLast(changes).getAuthor()),
        ImmutableSetMultimap.of()),
    // Squash notes an Skylark API expect last commit to be the first one.
    new Changes(changes.reverse(), ImmutableList.of()),
    baseline.get(),
    runHelper.getResolvedRef(),
    baselineForMergeImport);
```

### **🔍 What Happens to Your Commits**

1. **Multiple Commits Detected**: Copybara finds all commits between the baseline and your PR head
2. **Metadata from Last Commit**: Uses the message and author from the **last commit** only
3. **Single Migration Call**: Calls `migrator.migrate()` **once** with all changes combined
4. **3-Way Merge**: Performs one 3-way merge with the **combined** changes
5. **Single Destination Commit**: Creates **one commit** in the destination

### **📊 Example Scenario**

```bash
# Your PR has 3 commits:
commit abc123: "Add user authentication"
commit def456: "Fix validation bug" 
commit ghi789: "Add unit tests"

# CHANGE_REQUEST mode creates:
commit xyz999: "Add unit tests"  # Only the last commit message!
# But contains ALL the file changes from abc123 + def456 + ghi789
```

## 🚫 **Why Individual Commits Aren't Preserved**

### **1. Architectural Design**
- CHANGE_REQUEST is designed for **change requests** (PRs, Gerrit changes)
- The assumption is you want to **import the final state**, not the development history
- It treats the PR as a **single logical change** to be applied

### **2. 3-Way Merge Limitation**
- The 3-way merge process works on the **entire tree state**
- It compares: `Origin Final State` ↔ `Baseline` ↔ `Destination Current State`
- There's no mechanism to apply individual commits sequentially

### **3. Destination Compatibility**
- Many destinations expect a **single change request** (like creating one Gerrit change)
- Preserving history would require multiple destination operations

## 🛠️ **Workarounds and Alternatives**

### **Option 1: Use ITERATIVE Mode**
```bash
# This processes each commit individually
copybara copy.bara.sky my_workflow --mode=ITERATIVE
```

**Pros:**
- ✅ Preserves individual commits
- ✅ Each commit gets its own destination commit
- ✅ Maintains commit messages and authors

**Cons:**
- ❌ No 3-way merge (loses destination-specific changes)
- ❌ Not suitable for change requests with destination customizations
- ❌ May create conflicts if destination has diverged

### **Option 2: Use metadata.squash_notes**
```python
# In your copy.bara.sky
core.workflow(
    name = "my_workflow",
    origin = git.origin(url = "..."),
    destination = git.destination(url = "..."),
    mode = "CHANGE_REQUEST",
    transformations = [
        metadata.squash_notes(
            prefix = "Original commits:\n",
            show_author = True,
            show_description = True,
        ),
        # other transformations...
    ],
)
```

**Result:**
```
Add unit tests

Original commits:
- abc123: Add user authentication (by john@example.com)
- def456: Fix validation bug (by jane@example.com)  
- ghi789: Add unit tests (by bob@example.com)
```

**Pros:**
- ✅ Preserves commit information in the message
- ✅ Works with CHANGE_REQUEST mode
- ✅ Maintains 3-way merge benefits

**Cons:**
- ❌ Still only one commit in destination
- ❌ History is in text form, not git history

### **Option 3: Custom Implementation (Advanced)**

You could potentially create a custom destination that:
1. Receives the squashed change from CHANGE_REQUEST
2. Internally splits it back into individual commits
3. Applies each commit separately

**This would require:**
- Custom destination implementation
- Complex logic to reverse-engineer individual commits
- Handling of merge conflicts per commit

## 📋 **Summary**

| Mode | Individual Commits | 3-Way Merge | Use Case |
|------|-------------------|-------------|----------|
| **CHANGE_REQUEST** | ❌ No (always squashes) | ✅ Yes | Change requests with destination customizations |
| **ITERATIVE** | ✅ Yes | ❌ No | Clean migrations without destination changes |
| **SQUASH** | ❌ No (always squashes) | ❌ No | Simple state imports |

## 🎯 **Recommendation**

For **CHANGE_REQUEST mode**, the best approach is:

1. **Accept the squashing behavior** (it's by design)
2. **Use `metadata.squash_notes`** to preserve commit information in the message
3. **Focus on the logical change** rather than development history
4. **Use ITERATIVE mode** only if you don't need 3-way merging

The CHANGE_REQUEST mode is optimized for **importing the final state of a change request** while preserving destination customizations, not for maintaining detailed development history.
