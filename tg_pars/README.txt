Settings serializer round-trip tests

Placement:
  Create a folder named settings_tests beside your current tg_pars package folder,
  or as a child folder inside the directory that contains the files with `package tg_pars`.
  Put main.odin in that folder. The import `settings ".."` assumes the tests folder is
  inside the directory containing the serializer package.

Run from the settings_tests folder:
  odin run .

The test executable writes these files in its working directory:
  settings_test_flat.cfg
  settings_test_big.cfg
  settings_test_containers.cfg

The suite intentionally covers flat fields; a large nested struct containing strings,
fixed arrays, nested arrays, structs, enums, and enumerated arrays; and dynamic arrays,
fixed-capacity dynamic arrays, and maps.

Important: the attached `tg_pars` source currently has a line-by-line `tg_read` and does
not yet have dynamic-array / fixed-capacity dynamic-array / map branches in its reader and
writer. Therefore the nested and container tests are expected to fail until those pieces
are integrated. The flat test should provide a smaller baseline. I could not compile or
execute the suite here because an Odin compiler is not installed in this environment.
