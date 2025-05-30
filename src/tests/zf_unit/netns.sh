# ! /bin/bash
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: (c) 2019-2024 Advanced Micro Devices, Inc.

# launches command given in arguments into brand new netns
# fixes up state of lo interface to be up

if [ "$1" != "--" ]; then
  # reexecute script with new netns
  exec unshare -n "$0" "--" "$@"
fi

# Jenkins VM do not have this in the path - required for ifconfig
export PATH=$PATH:/usr/sbin

echo 0 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/ip_nonlocal_bind
echo 4096 > /proc/sys/vm/nr_hugepages
# we are in new namespace, get lo dev up and kick off the command
ifconfig lo up
shift

rm -f /dev/shm/zf_emu_*

name_in_list()
{
  name=$1
  list=$2
  if [ "$(echo "$list" | sed -e "s/ /\n/g" | grep "$name")" = "$name" ]; then
    return 0;
  else
    return 1;
  fi
}

testapp_name=$(basename $1)
if [ "${ZF_RUN_SLOW_TESTS:-1}" = "0" ] && (name_in_list "$testapp_name" "$ZF_SLOW_TESTS"); then
  echo "1..0 # SKIP not running $testapp_name as it is considered slow. Set ZF_RUN_SLOW_TESTS=1 to run it."
  exit 0
elif [ "${ZF_RUN_UNSTABLE_TESTS:-0}" = "0" ] && (name_in_list "$testapp_name" "$ZF_UNSTABLE_TESTS"); then
  echo "1..0 # SKIP not running $testapp_name as it is considered unstable. Set ZF_RUN_UNSTABLE_TESTS=1 to run it."
  exit 0
fi

output="$(timeout ${TEST_TIME_OUT:-120} $@)"
rc="$?"
echo "$output"
if [ "$rc" -ne 0 -a -n "$UT_OUTPUT" ]; then
  if [ ! -f "$UT_OUTPUT" ]; then
    output_dir="$(dirname $UT_OUTPUT)"
    if [ -n "$output_dir" -a ! -d "$output_dir" ]; then
      mkdir -p "$output_dir"
    fi
    touch "$UT_OUTPUT"
  fi

  echo "# Failed \`$(basename $@)\` in \`$TEST_TARGET\`" >> "$UT_OUTPUT"
  if [ "$rc" -eq 124 ]; then
    echo "Test timed out (rc=$rc)." >> "$UT_OUTPUT"
  else
    echo "Test returned $rc." >> "$UT_OUTPUT"
  fi

  echo "## Suggested Reproducer" >> "$UT_OUTPUT"
  echo "\`\`\`" >> "$UT_OUTPUT"
  echo "sudo env EF_VI_CTPIO_MODE=$EF_VI_CTPIO_MODE \\" >> "$UT_OUTPUT"
  echo "  ZF_ATTR=\"$ZF_ATTR\" \\" >> "$UT_OUTPUT"
  echo "  EXTRA_ZF_ATTR=\"$EXTRA_ZF_ATTR\" \\" >> "$UT_OUTPUT"
  echo "  $@" >> "$UT_OUTPUT"
  echo "\`\`\`" >> "$UT_OUTPUT"

  echo "## Test Log" >> "$UT_OUTPUT"
  echo "\`\`\`" >> "$UT_OUTPUT"
  echo "$output" >> "$UT_OUTPUT"
  echo "\`\`\`" >> "$UT_OUTPUT"
fi
exit 0
