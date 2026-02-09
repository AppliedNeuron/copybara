/*
 * Copyright (C) 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.copybara;

import static com.google.copybara.exception.ValidationException.checkCondition;

import com.beust.jcommander.Parameters;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.Iterables;
import com.google.copybara.config.LabelsAwareModule;
import com.google.copybara.config.Migration;
import com.google.copybara.config.SkylarkParser.ConfigWithDependencies;
import com.google.copybara.exception.CommandLineException;
import com.google.copybara.exception.RepoException;
import com.google.copybara.exception.ValidationException;
import com.google.copybara.revision.Revision;
import com.google.copybara.util.ExitCode;
import com.google.copybara.util.FileUtil;
import com.google.copybara.util.Glob;
import com.google.copybara.util.console.Console;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.annotation.Nullable;

/**
 * Command that lists the files included by a workflow's origin_files at a given reference. Resolves
 * the workflow's origin glob against the origin at the given ref (or HEAD) and prints one path per
 * line. Optionally prints only the glob expression (--globs-only) or writes to a file (--output).
 *
 * <p>Usage: copybara list_files copy.bara.sky WORKFLOW_NAME [REF] [--output=path]
 * [--globs-only]
 */
@Parameters(
    separators = "=",
    commandDescription =
        "Lists the files that match the workflow's origin_files at the given reference (or HEAD)."
            + " Output is one path per line. Use --globs-only to print only the glob expression;"
            + " use --output=path to write to a file.")
public class ListFilesCmd implements CopybaraCmd {

  private final ConfigLoaderProvider configLoaderProvider;
  private final ModuleSet moduleSet;

  public ListFilesCmd(ConfigLoaderProvider configLoaderProvider, ModuleSet moduleSet) {
    this.configLoaderProvider = com.google.common.base.Preconditions.checkNotNull(
        configLoaderProvider);
    this.moduleSet = com.google.common.base.Preconditions.checkNotNull(moduleSet);
  }

  @Override
  public ExitCode run(CommandEnv commandEnv)
      throws ValidationException, IOException, RepoException {
    ConfigFileArgs configFileArgs = commandEnv.getConfigFileArgs();
    if (configFileArgs == null) {
      throw new CommandLineException(
          "Configuration file missing for 'list_files' subcommand. Usage: copybara list_files"
              + " copy.bara.sky WORKFLOW_NAME [REF] [--output=path]");
    }

    ImmutableList<String> sourceRefs = configFileArgs.getSourceRefs();
    if (sourceRefs.size() > 1) {
      throw new CommandLineException(
          String.format(
              "list_files does not support multiple source_ref arguments: %s", sourceRefs));
    }
    @Nullable String sourceRef = Iterables.getFirst(sourceRefs, null);
    String workflowName = configFileArgs.getWorkflowName();

    updateEnvironment(workflowName);

    GeneralOptions generalOptions = commandEnv.getOptions().get(GeneralOptions.class);
    ListFilesOptions listFilesOptions = commandEnv.getOptions().get(ListFilesOptions.class);
    Console console = generalOptions.console();

    ConfigWithDependencies config =
        configLoaderProvider
            .newLoader(configFileArgs.getConfigPath(), sourceRef)
            .loadWithDependencies(console);

    // Only works for Workflows since we are required to have origin_files.
    Migration migration = config.getConfig().getMigration(workflowName);
    checkCondition(
        migration instanceof Workflow,
        "list_files is only supported for workflow migrations, not: %s",
        migration.getClass().getSimpleName());

    @SuppressWarnings("unchecked")
    Workflow<? extends Revision, ? extends Revision> workflow =
        (Workflow<? extends Revision, ? extends Revision>) migration;

    // Resolve ref and checkout to list resolved files.
    Path checkoutDir =
        generalOptions.getDirFactory().newTempDir("list_files_checkout");
    try {
      listFilesWithCheckout(
          workflow, sourceRef, checkoutDir, generalOptions);

      Glob originFiles = workflow.getOriginFiles();
      ImmutableList<String> paths = FileUtil.listMatchingFiles(checkoutDir, originFiles);

      if (paths.isEmpty()) {
        console.warn(
            "list_files: No files matched. Check that the origin checkout succeeded and that"
                + " origin_files matches the repo layout.");
      }

      String content = String.join("\n", paths) + (paths.isEmpty() ? "" : "\n");

      if (listFilesOptions.getOutputPath() != null) {
        // Get absolute path to output file.
        Path outputPath =
            generalOptions.getFileSystem().getPath(listFilesOptions.getOutputPath());
        if (!outputPath.isAbsolute()) {
          outputPath = commandEnv.getWorkdir().resolve(listFilesOptions.getOutputPath());
        }
        Path parent = outputPath.getParent();

        // Create parent directories if they don't exist.
        if (parent != null) {
          Files.createDirectories(parent);
        }

        // Write content to output file.
        Files.writeString(outputPath, content, StandardCharsets.UTF_8);
        console.verboseFmt("Wrote %d paths to %s", paths.size(), outputPath);
      } else {
        // Print file list to stdout so callers (e.g. Python release tool) can capture it.
        // Task/INFO/WARN go to stderr via console; only the path list goes to stdout.
        PrintStream stdout = System.out;
        stdout.print(content);
      }
      return ExitCode.SUCCESS;
    } finally {
      FileUtil.deleteRecursively(checkoutDir);
    }
  }

  /**
   * Performs checkout so that we can list matching files. Uses a generic type so that the origin's
   * revision type is preserved for the checkout call.
   */
  private <O extends Revision, D extends Revision> void listFilesWithCheckout(
      Workflow<O, D> workflow,
      @Nullable String sourceRef,
      Path checkoutDir,
      GeneralOptions generalOptions)
      throws RepoException, ValidationException {
    O resolvedRef =
        generalOptions.repoTask(
            "origin.resolve",
            () -> workflow.getOrigin().resolve(sourceRef));
    generalOptions.repoTask(
        "origin.checkout",
        () -> {
          workflow
              .getOrigin()
              .newReader(workflow.getOriginFiles(), workflow.getAuthoring())
              .checkout(resolvedRef, checkoutDir);
          return null;
        });
  }

  private void updateEnvironment(String workflowName) {
    for (Object module : moduleSet.getModules().values()) {
      if (module instanceof LabelsAwareModule m) {
        m.setWorkflowName(workflowName);
      }
    }
  }

  @Override
  public String name() {
    return "list_files";
  }
}
