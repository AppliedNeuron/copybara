# How to Enable Copybara Commit Search Logging

## Overview
The logging we added to track commit searches and GitOrigin-RevID lookups uses Flogger, which requires specific configuration to actually print to the console. Here are several ways to enable it.

## Method 1: Use the Modified Copybara (Recommended)

I've modified the `Main.java` file to enable console logging by default. Now when you run Copybara normally, you should see the logs:

```bash
# Normal Copybara command - logs will now appear in console
copybara copy.bara.sky workflow_name
```

## Method 2: Use the Helper Script

I've created a helper script that ensures logging is enabled:

```bash
# Use the helper script
./run_with_logging.sh copy.bara.sky workflow_name
```

## Method 3: Manual JVM Configuration

If you want to manually configure logging, you can set the JVM property:

```bash
# Set logging configuration via JVM property
java -Djava.util.logging.config.file=logging.properties -jar copybara.jar copy.bara.sky workflow_name
```

Create a `logging.properties` file:
```properties
handlers=java.util.logging.ConsoleHandler,java.util.logging.FileHandler
.level=INFO
java.util.logging.ConsoleHandler.level=INFO
java.util.logging.ConsoleHandler.formatter=java.util.logging.SimpleFormatter
java.util.logging.ConsoleHandler.encoding=UTF-8
java.util.logging.FileHandler.level=INFO
java.util.logging.FileHandler.pattern=copybara-%g.log
java.util.logging.FileHandler.count=10
java.util.logging.FileHandler.formatter=java.util.logging.SimpleFormatter
java.util.logging.SimpleFormatter.format=%1$tY-%1$tm-%1$td %1$tH:%1$tM:%1$tS %4$-6s %2$s %5$s%6$s%n
```

## Method 4: Environment Variable

You can also set the logging configuration via environment variable:

```bash
# Set logging configuration via environment
export JAVA_OPTS="-Djava.util.logging.config.file=logging.properties"
copybara copy.bara.sky workflow_name
```

## What You'll See

With logging enabled, you'll see output like this:

```
2024-01-15 10:30:45 INFO  com.google.copybara.git.GitDestination Starting GitOrigin-RevID search from commit abc123def456 with grep pattern: ^GitOrigin-RevId: 
2024-01-15 10:30:45 INFO  com.google.copybara.git.GitRepository Executing: [log, --no-color, --format=...]
2024-01-15 10:30:45 INFO  com.google.copybara.git.GitRepository Log command returned 5 entries
2024-01-15 10:30:45 INFO  com.google.copybara.git.GitRepository Searched commit: SHA=abc123def456, Author=John Doe, Message=Initial commit
2024-01-15 10:30:45 INFO  com.google.copybara.git.GitRepository Searched commit: SHA=def456ghi789, Author=Jane Smith, Message=Add feature X
2024-01-15 10:30:45 INFO  com.google.copybara.DestinationStatusVisitor Visiting commit: SHA=abc123def456, Author=John Doe, Message=Initial commit
2024-01-15 10:30:45 INFO  com.google.copybara.DestinationStatusVisitor No GitOrigin-RevId label found in commit abc123def456
2024-01-15 10:30:45 INFO  com.google.copybara.DestinationStatusVisitor Visiting commit: SHA=def456ghi789, Author=Jane Smith, Message=Add feature X
2024-01-15 10:30:45 INFO  com.google.copybara.DestinationStatusVisitor Found GitOrigin-RevId label in commit def456ghi789: [origin_commit_123]
2024-01-15 10:30:45 INFO  com.google.copybara.DestinationStatusVisitor GitOrigin-RevID found: origin_commit_123 in commit def456ghi789 for file src/main.java
```

## Log Levels

The logging uses these levels:
- **INFO**: Normal operation messages (what we added)
- **WARNING**: Warning messages
- **SEVERE**: Error messages

## Troubleshooting

### If you don't see any logs:

1. **Check if logging is disabled**: Look for `--nologging` flag in your command
2. **Verify the configuration**: Make sure the logging configuration is being applied
3. **Check log files**: Even if console logging doesn't work, logs should still be written to `copybara-*.log` files

### If you see too many logs:

You can filter the logs by class:
```bash
# Only show our specific logging classes
copybara copy.bara.sky workflow_name 2>&1 | grep -E "(GitDestination|DestinationStatusVisitor|GitRepository)"
```

### If you want to disable logging:

```bash
# Disable logging completely
copybara --nologging copy.bara.sky workflow_name
```

## Log File Locations

- **Console**: Logs appear in your terminal
- **Files**: Logs are also written to `copybara-*.log` files in the output directory
- **Default location**: Usually `~/copybara/out/copybara-*.log`

## Benefits of the Logging

1. **Debugging**: See exactly which commits are being searched
2. **Performance**: Monitor how many commits are processed
3. **Traceability**: Full audit trail of the search process
4. **Troubleshooting**: Identify why GitOrigin-RevID wasn't found

## Example Usage

```bash
# Run with logging enabled (Method 1 - after our modification)
copybara copy.bara.sky workflow_name

# Or use the helper script (Method 2)
./run_with_logging.sh copy.bara.sky workflow_name

# Or with manual configuration (Method 3)
java -Djava.util.logging.config.file=logging.properties -jar copybara.jar copy.bara.sky workflow_name
```

The logging will help you understand exactly how Copybara searches for commits and finds GitOrigin-RevID labels, making it much easier to debug migration issues.


