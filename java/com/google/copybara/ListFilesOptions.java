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

import com.beust.jcommander.Parameter;
import com.beust.jcommander.Parameters;
import com.google.copybara.Option;
import javax.annotation.Nullable;

/**
 * Options for the {@code list_files} command. Controls whether to output resolved paths or only
 * the origin_files glob expression, and where to write output.
 */
@Parameters(separators = "=")
public class ListFilesOptions implements Option {

  @Nullable
  @Parameter(
      names = "--output",
      description =
          "Write the file list to this path instead of stdout. Used only when listing resolved"
              + " paths (default behavior).")
  private String outputPath;

  @Nullable
  public String getOutputPath() {
    return outputPath;
  }

}
