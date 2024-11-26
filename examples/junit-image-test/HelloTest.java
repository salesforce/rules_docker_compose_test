/*
 * Copyright (c) 2023, Salesforce, Inc.
 * SPDX-License-Identifier: Apache-2
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.salesforce.rules_docker_compose_test.HelloTest;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HelloTest {

    @Test
     void helloWorldContainsHello() {
        // Testing that the $JAVA_HOME/bin binaries are available
        ProcessBuilder processBuilder = new ProcessBuilder(new String[]{"sh", "-c", "jstat --help"});
        Process process = processBuilder.start();
        int exitValue = process.waitFor();
        assertEquals(0, exitValue);
        assertTrue("Hello World!".contains("Hello"));
    }
}
