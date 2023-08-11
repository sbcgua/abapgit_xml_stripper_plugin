class zcl_abapgit_xml_stripper definition
  public
  final
  create private .

  public section.

    types:
      ty_command type c length 1.

    constants:
      begin of c_command,
        remove type ty_command value 'R',
      end of c_command.

    types:
      begin of ty_rule,
        command  type ty_command,
        obj_type type zif_abapgit_definitions=>ty_item-obj_type,
        obj_name type zif_abapgit_definitions=>ty_item-obj_type,
        paths    type string_table,
      end of ty_rule.

    types:
      tty_rules        type standard table of ty_rule with default key,
      tts_rules_by_obj type sorted table of ty_rule with non-unique key obj_type obj_name.

    types:
      begin of ty_config,
        rules type tts_rules_by_obj,
      end of ty_config.

    class-methods process_files
      importing
        iv_config_filename type string optional
        iv_config type string optional
      changing
        ct_local  type zif_abapgit_definitions=>ty_files_item_tt
        ct_remote type zif_abapgit_git_definitions=>ty_files_tt
      raising
        zcx_abapgit_exception.

    methods constructor
      importing
        iv_config_blob type xstring
      raising
        zcx_abapgit_exception.

  protected section.
  private section.

    data ms_config type ty_config.

    class-methods find_strip_config
      importing
        it_remote           type zif_abapgit_git_definitions=>ty_files_tt
        iv_config_file_name type string optional
      returning
        value(rv_config_blob) type xstring.

    class-methods identify_object_main_xml
      importing
        iv_filename    type string
      returning
        value(rs_item) type zif_abapgit_definitions=>ty_item.

    methods _process_files
      changing
        ct_local  type zif_abapgit_definitions=>ty_files_item_tt
        ct_remote type zif_abapgit_git_definitions=>ty_files_tt
      raising
        zcx_abapgit_exception.

    methods get_strip_paths_for_item
      importing
        is_item         type zif_abapgit_definitions=>ty_item
      returning
        value(rt_paths) type string_table.

    methods strip_file
      importing
        is_item      type zif_abapgit_definitions=>ty_item
      changing
        cv_file_blob type xstring
      raising
        zcx_abapgit_exception.

ENDCLASS.



CLASS ZCL_ABAPGIT_XML_STRIPPER IMPLEMENTATION.


  method constructor.
    ms_config = lcl_config_parser=>parse_config( cl_abap_codepage=>convert_from( iv_config_blob ) ).
  endmethod.


  method find_strip_config.

    field-symbols <file> like line of it_remote.

    read table it_remote assigning <file> with key path = '/' filename = iv_config_file_name.
    if sy-subrc = 0 and <file>-data is not initial.
      rv_config_blob = <file>-data.
    endif.

  endmethod.


  method get_strip_paths_for_item.

    field-symbols <rule> like line of ms_config-rules.

    read table ms_config-rules assigning <rule> with key obj_type = is_item-obj_type obj_name = is_item-obj_name.
    if sy-subrc = 0.
      append lines of <rule>-paths to rt_paths.
    endif.

    read table ms_config-rules assigning <rule> with key obj_type = is_item-obj_type.
    if sy-subrc = 0.
      append lines of <rule>-paths to rt_paths.
    endif.

  endmethod.


  method identify_object_main_xml.

    data lv_name type string.
    data lv_type type string.
    data lv_ext  type string.

    " Guess object type and name
    split to_upper( iv_filename ) at '.' into lv_name lv_type lv_ext.

    " Handle namespaces
    replace all occurrences of '#' in lv_name with '/'.
    replace all occurrences of '#' in lv_type with '/'.
    replace all occurrences of '#' in lv_ext with '/'.

    " Get original object name
    lv_name = cl_http_utility=>unescape_url( lv_name ).

    if lv_ext = 'XML' and strlen( lv_type ) = 4.
      rs_item-obj_type = lv_type.
      rs_item-obj_name = lv_name.
    endif.

  endmethod.


  method process_files.

    data lv_config_blob type xstring.
    data lo_stripper type ref to zcl_abapgit_xml_stripper.

    if boolc( iv_config is initial ) = boolc( iv_config_filename is initial ).
      zcx_abapgit_exception=>raise( 'XML_STRIPPER: config or config filename must be provided' ).
    endif.

    if iv_config_filename is not initial.
      lv_config_blob = find_strip_config(
        it_remote           = ct_remote
        iv_config_file_name = iv_config_filename ).
      if lv_config_blob is initial.
        return.
      endif.
    else.
      lv_config_blob = cl_abap_codepage=>convert_to( iv_config ).
    endif.

    create object lo_stripper exporting iv_config_blob = lv_config_blob.

    lo_stripper->_process_files(
      changing
        ct_local  = ct_local
        ct_remote = ct_remote ).

  endmethod.


  method strip_file.

    data lt_paths type string_table.

    lt_paths = get_strip_paths_for_item( is_item ).

    if lines( lt_paths ) > 0.
      lcl_stripper=>process_file(
        exporting
          it_paths = lt_paths
        changing
          cv_blob = cv_file_blob ).
    endif.

  endmethod.


  method _process_files.

    data ls_item type zif_abapgit_definitions=>ty_item.

    field-symbols <rfile> like line of ct_remote.
    field-symbols <lfile> like line of ct_local.

    if ms_config is initial.
      return.
    endif.

    loop at ct_remote assigning <rfile>.
      ls_item = identify_object_main_xml( <rfile>-filename ).
      check ls_item is not initial. " Not xml -> skip
      strip_file(
        exporting
          is_item = ls_item
        changing
          cv_file_blob = <rfile>-data ).
    endloop.

    loop at ct_local assigning <lfile>.
      ls_item = identify_object_main_xml( <lfile>-file-filename ).
      check ls_item is not initial. " Not xml -> skip
      strip_file(
        exporting
          is_item = ls_item
        changing
          cv_file_blob = <lfile>-file-data ).
    endloop.

  endmethod.
ENDCLASS.
