class lcl_utils definition final.
  public section.
    class-methods open_cur_node_copy_with_attrs
      importing
        ii_reader type ref to if_sxml_reader
        ii_writer type ref to if_sxml_writer.

    class-methods join_path
      importing
        it_stack       type string_table
      returning
        value(rv_path) type string.

endclass.

class lcl_utils implementation.
  method open_cur_node_copy_with_attrs.

    ii_writer->open_element(
      prefix = ii_reader->prefix
      nsuri  = ii_reader->nsuri
      name   = ii_reader->name ).
    do.
      ii_reader->next_attribute( ).
      if ii_reader->node_type <> if_sxml_node=>co_nt_attribute.
        exit.
      endif.
      ii_writer->write_attribute(
        name  = ii_reader->name
        value = ii_reader->value ).
    enddo.

  endmethod.

  method join_path.
    loop at it_stack assigning field-symbol(<seg>).
      rv_path = '/' && <seg> && rv_path.
    endloop.
  endmethod.
endclass.

**********************************************************************

class lcl_stripper definition final create private.

  public section.
    methods constructor
      importing
        iv_blob  type xstring
        it_paths type string_table.

    class-methods process_file
      importing
        it_paths type string_table
      changing
        !cv_blob type xstring
      raising
        zcx_abapgit_exception.

  private section.
    data mi_reader type ref to if_sxml_reader.
    data mi_writer type ref to if_sxml_writer.
    data mt_paths type string_table.
    data mo_xml_writer type ref to cl_sxml_string_writer.

    methods render_blob
      returning
        value(rv_blob) type xstring.
    methods do_processing
      raising
        zcx_abapgit_exception cx_sxml_parse_error.
    methods validate_and_copy
      importing
        iv_tag_name  type string
        iv_node_type type if_sxml_node=>node_type
        iv_read_next type abap_bool default abap_true
      raising
        zcx_abapgit_exception cx_sxml_parse_error.
    methods do_remove
      raising
        zcx_abapgit_exception cx_sxml_parse_error.
    methods is_to_remove
      importing
        iv_cur_path   type string
      returning
        value(rv_yes) type abap_bool.

endclass.

class lcl_stripper implementation.

  method process_file.
    data lo_processor type ref to lcl_stripper.
    data lx_parse_error type ref to cx_root.

    create object lo_processor
      exporting
        it_paths = it_paths
        iv_blob  = cv_blob.

    try.
        lo_processor->do_processing(  ).
      catch cx_sxml_parse_error into lx_parse_error.
        zcx_abapgit_exception=>raise( |XML_STRIPPER: Parsing failed { lx_parse_error->get_text( ) }| ).
    endtry.

    cv_blob = lo_processor->render_blob( ).
  endmethod.

  method constructor.
    mt_paths      = it_paths.
    mi_reader     = cl_sxml_string_reader=>create( iv_blob ).
    mo_xml_writer = cl_sxml_string_writer=>create( encoding = 'utf-8' ).
    mi_writer     = mo_xml_writer.
  endmethod.

  method render_blob.
    rv_blob = mo_xml_writer->get_output( ).
  endmethod.

  method do_processing.

    " Expect asx:abap XML structure
    validate_and_copy(
      iv_tag_name  = 'abapGit'
      iv_node_type = if_sxml_node=>co_nt_element_open ).
    validate_and_copy(
      iv_tag_name  = 'asx:abap'
      iv_node_type = if_sxml_node=>co_nt_element_open ).
    validate_and_copy(
      iv_tag_name  = 'asx:values'
      iv_node_type = if_sxml_node=>co_nt_element_open ).

    do_remove( ).

    validate_and_copy(
      iv_read_next = abap_false " already read in do_remove
      iv_tag_name  = 'asx:values'
      iv_node_type = if_sxml_node=>co_nt_element_close ).
    validate_and_copy(
      iv_tag_name  = 'asx:abap'
      iv_node_type = if_sxml_node=>co_nt_element_close ).
    validate_and_copy(
      iv_tag_name  = 'abapGit'
      iv_node_type = if_sxml_node=>co_nt_element_close ).

    mi_reader->next_node( ).
    if not ( mi_reader->node_type = if_sxml_node=>co_nt_final ).
      zcx_abapgit_exception=>raise( |XML_STRIPPER: Unexpected XML structure: EOF expected| ).
    endif.

  endmethod.

  method validate_and_copy.

    data lv_prefix type string.
    data lv_name type string.
    data lv_real_tag_name type string.

    split iv_tag_name at ':' into lv_prefix lv_name.
    if lv_name is initial.
      lv_name = lv_prefix.
      clear lv_prefix.
    endif.

    if iv_read_next = abap_true.
      mi_reader->next_node( ).
    endif.

    if not ( mi_reader->node_type = iv_node_type and mi_reader->prefix = lv_prefix and mi_reader->name = lv_name ).
      if mi_reader->prefix is not initial.
        lv_real_tag_name = |{ mi_reader->prefix }:{ mi_reader->name }|.
      else.
        lv_real_tag_name = mi_reader->name.
      endif.
      zcx_abapgit_exception=>raise( |XML_STRIPPER: Unexpected XML structure [{ iv_node_type }]: { lv_real_tag_name } instead of { iv_tag_name }| ).
    endif.

    if mi_reader->node_type = if_sxml_node=>co_nt_element_open.
      lcl_utils=>open_cur_node_copy_with_attrs(
        ii_reader = mi_reader
        ii_writer = mi_writer ).
    elseif mi_reader->node_type = if_sxml_node=>co_nt_element_close.
      mi_writer->close_element( ).
    else.
      zcx_abapgit_exception=>raise( |XML_STRIPPER: Unexpected node type [{ iv_node_type }] in validate_and_copy| ).
    endif.

  endmethod.

  method do_remove.

    data lt_stack type string_table.
    data lv_cur_path type string.
    data lv_stack_top type string.
    data lv_elem_depth type i.
    data lv_start_skip_at type i.

    do.
      mi_reader->next_node( ).
      if mi_reader->node_type = if_sxml_node=>co_nt_final.
        zcx_abapgit_exception=>raise( |XML_STRIPPER: Unexpected EOF| ).
      endif.

      case mi_reader->node_type.
        when if_sxml_node=>co_nt_element_open.
          insert to_upper( mi_reader->name ) into lt_stack index 1.
          lv_elem_depth = lv_elem_depth + 1.
          lv_cur_path   = to_upper( lcl_utils=>join_path( lt_stack ) ).

          if lv_start_skip_at = 0 and is_to_remove( lv_cur_path ) = abap_true.
            lv_start_skip_at = lv_elem_depth.
          endif.

          if lv_start_skip_at = 0.
            mi_writer->open_element( name = mi_reader->name ).
          endif.

        when if_sxml_node=>co_nt_element_close.
          lv_elem_depth = lv_elem_depth - 1.
          if lv_elem_depth < 0. " wrapping tag closes
            exit.
          endif.

          read table lt_stack index 1 into lv_stack_top.
          assert sy-subrc = 0.

          if to_upper( mi_reader->name ) <> lv_stack_top.
            zcx_abapgit_exception=>raise( |XML_STRIPPER: Unexpected closing node type { lv_stack_top }| ).
          endif.

          if lv_start_skip_at = 0.
            mi_writer->close_element( ).
          endif.

          delete lt_stack index 1.
          lv_cur_path = to_upper( lcl_utils=>join_path( lt_stack ) ).

          if lv_start_skip_at > 0 and lv_elem_depth < lv_start_skip_at.
            lv_start_skip_at = 0.
          endif.

        when if_sxml_node=>co_nt_value.

          if lv_start_skip_at = 0.
            mi_writer->write_value( mi_reader->value ).
          endif.

        when others.
          zcx_abapgit_exception=>raise( 'Unexpected node type' ).
      endcase.

    enddo.

  endmethod.

  method is_to_remove.

    data lv_path_len type i.
    field-symbols <path> like line of mt_paths.

    loop at mt_paths assigning <path>.
      lv_path_len = strlen( <path> ).
      if strlen( iv_cur_path ) >= lv_path_len and find( val = iv_cur_path sub = <path> len = lv_path_len ) = 0.
        rv_yes = abap_true.
        exit.
      endif.
    endloop.

  endmethod.

endclass.

**********************************************************************

class lcl_config_parser definition final.
  public section.
    class-methods parse_config
      importing
        iv_config        type string
      returning
        value(rs_config) type zcl_abapgit_xml_stripper=>ty_config
      raising
        zcx_abapgit_exception.

  private section.
    class-methods parse_remove_args
      importing
        iv_args   type string
      changing
        cs_config type zcl_abapgit_xml_stripper=>ty_config
      raising
        zcx_abapgit_exception.
endclass.

class lcl_config_parser implementation.

  method parse_config.

    data lt_lines  type string_table.
    data lv_config like iv_config.
    data lv_cmd    type string.
    data lv_rest   type string.
    field-symbols <line> type string.

    lv_config = replace(
      val  = iv_config
      sub  = cl_abap_char_utilities=>cr_lf
      with = cl_abap_char_utilities=>newline ).

    split lv_config at cl_abap_char_utilities=>newline into table lt_lines.

    loop at lt_lines assigning <line> where table_line is not initial.

      split <line> at ` ` into lv_cmd lv_rest.
      condense: lv_cmd, lv_rest.
      lv_cmd = to_upper( lv_cmd ).

      case lv_cmd.
        when 'REMOVE'.
          parse_remove_args(
            exporting
              iv_args = lv_rest
            changing
              cs_config = rs_config ).

        when others.
          zcx_abapgit_exception=>raise( |XML_STRIPPER: Unexpected procesing command { lv_cmd }| ).
      endcase.

    endloop.


  endmethod.


  method parse_remove_args.

    data lv_obj type string.
    data lv_obj_name_pre type string.
    data lv_obj_type type zcl_abapgit_xml_stripper=>ty_rule-obj_type.
    data lv_obj_name type zcl_abapgit_xml_stripper=>ty_rule-obj_name.
    data lv_path type string.
    data lv_len type i.
    data ls_rule like line of cs_config-rules.

    field-symbols <rule> like ls_rule.

    split iv_args at ':' into lv_obj lv_path.
    condense: lv_obj, lv_path.

    if find( val = lv_obj sub = '(' ) >= 0.
      split lv_obj at '(' into lv_obj_type lv_obj_name_pre.
      lv_len = strlen( lv_obj_name_pre ).
      if substring( val = lv_obj_name_pre off = lv_len - 1 ) <> ')'.
        zcx_abapgit_exception=>raise( |XML_STRIPPER: Incorrect obj name delimiters "{ lv_obj }"| ).
      endif.
      lv_obj_name = substring( val = lv_obj_name_pre len = lv_len - 1 ). " Buf overflow check ?
    else.
      lv_obj_type = lv_obj.
      clear lv_obj_name.
    endif.

    if lv_obj_type is initial.
      zcx_abapgit_exception=>raise( |XML_STRIPPER: Object type cannot be empty "{ lv_obj }"| ).
    endif.

    if lv_path is initial.
      zcx_abapgit_exception=>raise( |XML_STRIPPER: Path cannot be empty "{ lv_obj }"| ).
    endif.

    read table cs_config-rules assigning <rule>
      with key
        obj_name = lv_obj_name
        obj_type = lv_obj_type
        command  = zcl_abapgit_xml_stripper=>c_command-remove.
    if sy-subrc <> 0.
      ls_rule-command  = zcl_abapgit_xml_stripper=>c_command-remove.
      ls_rule-obj_type = lv_obj_type.
      ls_rule-obj_name = lv_obj_name.
      insert ls_rule into table cs_config-rules assigning <rule>.
      assert sy-subrc = 0.
    endif.

    lv_path = to_upper( lv_path ).
    append lv_path to <rule>-paths.

  endmethod.
endclass.
