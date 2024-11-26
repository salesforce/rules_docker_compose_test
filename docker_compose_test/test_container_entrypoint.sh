# Copyright (c) 2023, Salesforce, Inc.
# SPDX-License-Identifier: Apache-2

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# if JAVA_HOME is not set, just default to /usr (works if /usr/bin/java exists)
if [[ -z "$JAVA_HOME" ]]; then
    export JAVA_HOME="/usr"
# this is used if JAVA_HOME contains an * (if version changes regularly this can be useful)
elif [[ "$JAVA_HOME" == *"\*"* ]]; then
    export JAVA_HOME=$(find $JAVA_HOME -maxdepth 1 | head -n 1)
fi

export PATH=$JAVA_HOME/bin:$PATH

TEST_UBER_JAR=$(find ./ -maxdepth 1 -name '*_uber_jar_deploy.jar')
JUNIT_PLATFORM_CONSOLE_STANDALONE_JAR=$(find ./ -maxdepth 1 -name '*junit-platform-console-standalone*.jar')

# TODO: need to find a better solution than adding all of the jars to the class-path below
# The only one we should need to add is the fat jar because it should contain the rest of them..
# However, it seems like we need to add all of the spring/spring-boot jars like this.
JARS=$(find ./ -maxdepth 1 -name '*.jar' ! -name '*_uber_jar_deploy.jar')
CLASS_PATH_STRING=""
for JAR in $JARS; do
  CLASS_PATH_STRING="$CLASS_PATH_STRING --class-path $JAR"
done

echo "foo"
echo $JAVA_HOME
echo $PATH
ls "/usr/bin"

# JVM_ARGS can be set in the docker-compose file.
# JUNIT_PARAMS can be set in the docker-compose file to filter for specific tests
# e.g. --include-classname com.something.integration.*
cmd="$JAVA_HOME/bin/java -jar $JVM_ARGS $JUNIT_PLATFORM_CONSOLE_STANDALONE_JAR \
    --scan-class-path --fail-if-no-tests $CLASS_PATH_STRING --class-path $TEST_UBER_JAR $JUNIT_PARAMS"
echo $cmd
$cmd
