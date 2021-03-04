# abapgit xml stripper plugin

This plugin is designed to clean up certain XML parts when deploying your package to another system with another version. Frequently, deplying to another system triggers some changes in XMLs which depend on version (e.g. HANA) or translation status. This plugin allows to remove certai XML nodes before comparing local and remote files.

![image](./image.png)

## Installation

Install it using abapgit. No other specific procedures.

## Usage

1) Implement `ZCL_ABAPGIT_USER_EXIT` (with interface `ZIF_ABAPGIT_EXIT`) - a class used to enhance abapgit functionality. See also [abapgit docs](https://docs.abapgit.org/ref-exits.html)
2) Implement `pre_calculate_repo_status` method

```abap
    zcl_abapgit_xml_stripper=>process_files(
      exporting
        iv_config_filename = '.xmlstrip.config'
      changing
        ct_local  = ct_local
        ct_remote = ct_remote ).
```

3) Add `.xmlstrip.config` to the root of your repo. This is a text file with the following content (case insensitive)

```
remove DTEL:/dd04v/FLD1
remove DTEL:/dd04v/FLD2
remove DTEL(ZXXX):/dd04v/FLD3
remove DOMA:/DD01V/xyz
```

4) Alternatively, you can also directly specify the config via `iv_config` params (e.g. entered via direct user dialog)

```abap
    zcl_abapgit_xml_stripper=>process_files(
      exporting
        iv_config =
          |remove DTEL:/dd04v/FLD1\n| &
          |remove DTEL:/dd04v/FLD2\n|
      changing
        ct_local  = ct_local
        ct_remote = ct_remote ).
```

So a config line can be for all object types or for the specific one. The node is removed both in local and remote files **before diff**. Importantly: the deserialization is not affected ! The original file without stripping is deserialized !

