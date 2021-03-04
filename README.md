# abapgit xml stripper plugin

TODO more docs ...

1) Implement `ZCL_ABAPGIT_USER_EXIT` (with interface `ZIF_ABAPGIT_EXIT`)
2) Implement `pre_calculate_repo_status` method

```abap
    zcl_abapgit_xml_stripper=>process_files(
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

So a config line can be for all object types or for the specific one. The node is removed both in local and remote files **before diff**. Importantly: the deserialization is not affected ! The original file without stripping is deserialized !

