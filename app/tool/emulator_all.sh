#!/bin/bash
# Runs the suites chosen by the workflow input: smoke, picker or both.
case "${SUITE:-both}" in
  smoke) bash app/tool/emulator_smoke.sh ;;
  picker) timeout 1500 bash app/tool/emulator_picker.sh ;;
  *) bash app/tool/emulator_smoke.sh; timeout 1500 bash app/tool/emulator_picker.sh ;;
esac
exit 0
