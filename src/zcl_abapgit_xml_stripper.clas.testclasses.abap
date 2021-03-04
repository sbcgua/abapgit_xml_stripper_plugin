class ltcl_stripper_components_test definition for testing final
  duration short
  risk level harmless.

  private section.

    methods parse_config for testing raising zcx_abapgit_exception.
    methods process_remove_command for testing raising zcx_abapgit_exception.

endclass.

class ltcl_stripper_components_test implementation.

  method process_remove_command.

    data lt_paths type string_table.

    lt_paths = value #( ( `/DATA/STARTING_FOLDER` ) ( `/DATA/IGNORE` ) ).

    data(lv_input) = |<?xml version="1.0" encoding="utf-8"?>\n| &
      |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
      | <asx:values>\n| &
      |  <DATA>\n| &
      |   <MASTER_LANGUAGE>E</MASTER_LANGUAGE>\n| &
      |   <STARTING_FOLDER>/src/</STARTING_FOLDER>\n| &
      |   <FOLDER_LOGIC>PREFIX</FOLDER_LOGIC>\n| &
      |   <IGNORE>\n| &
      |    <item>/.travis.yml</item>\n| &
      |    <item>/CONTRIBUTING.md</item>\n| &
      |   </IGNORE>\n| &
      |  </DATA>\n| &
      | </asx:values>\n| &
      |</asx:abap>\n|.

    data(lv_exp) = |<?xml version="1.0" encoding="utf-8"?>\n| &
      |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
      | <asx:values>\n| &
      |  <DATA>\n| &
      |   <MASTER_LANGUAGE>E</MASTER_LANGUAGE>\n| &
      |   <FOLDER_LOGIC>PREFIX</FOLDER_LOGIC>\n| &
      |  </DATA>\n| &
      | </asx:values>\n| &
      |</asx:abap>|.

    data(lv_blob_input) = cl_abap_codepage=>convert_to(
      source   = lv_input
      codepage = 'UTF-8' ).

    data(lv_blob_exp) = cl_abap_codepage=>convert_to(
      source   = lv_exp
      codepage = 'UTF-8' ).

    lcl_stripper=>process_file(
      exporting
        it_paths = lt_paths
      changing
        cv_blob = lv_blob_input ).

    cl_sxiveri_xml_comparator=>compare(
      exporting
        xml1      = lv_blob_input
        xml2      = lv_blob_exp
      importing
        are_equal = data(lv_equal) ).

    cl_abap_unit_assert=>assert_true( lv_equal ).

  endmethod.

  method parse_config.

    data(lv_config) =
      |remove DTEL:/dd04v/FLD1\n| &
      |remove DTEL:/dd04v/FLD2\n| &
      |remove DTEL(ZXXX):/dd04v/FLD3\n| &
      |remove DOMA:/DD01V/xyz\n|.

    data(lt_conf_act) = lcl_config_parser=>parse_config( lv_config ).

    data lt_conf_exp like lt_conf_act.

    lt_conf_exp = value #( rules = value #(
      ( command = 'R' obj_type = 'DOMA' obj_name = ''     paths = value #( ( `/DD01V/XYZ` ) ) )
      ( command = 'R' obj_type = 'DTEL' obj_name = ''     paths = value #( ( `/DD04V/FLD1` ) ( `/DD04V/FLD2` ) ) )
      ( command = 'R' obj_type = 'DTEL' obj_name = 'ZXXX' paths = value #( ( `/DD04V/FLD3` ) ) )
    ) ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_conf_act
      exp = lt_conf_exp ).

  endmethod.

endclass.

**********************************************************************

class ltcl_stripper_scenarios definition final for testing
  duration short
  risk level harmless.

  public section.

    types:
      begin of ty_local_remote,
        local  type zif_abapgit_definitions=>ty_files_item_tt,
        remote type zif_abapgit_definitions=>ty_files_tt,
      end of ty_local_remote.

    methods prepare_mock
      exporting
        es_input  type ty_local_remote
        es_exp    type ty_local_remote.

  private section.
    methods no_change_if_no_config for testing raising zcx_abapgit_exception.
    methods happy_path for testing raising zcx_abapgit_exception.

endclass.

class ltcl_stripper_scenarios implementation.
  method prepare_mock.

    es_input = value #(
      local = value #(
        ( file = value #( path = `` filename = `zyyy.dtel.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD04V>\n| &
          |   <USEFULL>y</USEFULL>\n| &
          |   <fld1>1</fld1>\n| &
          |   <fld2>2</fld2>\n| &
          |   <fld3>3</fld3>\n| &
          |  </DD04V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
          item = value #( obj_type = 'DTEL' obj_name = 'ZYYY' devclass = 'ZTMP' )
        )
      )
      remote = value #(
        ( path = `/` filename = `.xmlstrip.config` data = cl_abap_codepage=>convert_to( source =
          |remove DTEL:/dd04v/FLD1\n| &
          |remove DTEL:/dd04v/FLD2\n| &
          |remove DTEL(ZXXX):/dd04v/FLD3\n| &
          |remove DOMA:/DD01V/xyz\n| ) )
        ( path = `` filename = `zxxx.dtel.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD04V>\n| &
          |   <USEFULL>x</USEFULL>\n| &
          |   <fld1>1</fld1>\n| &
          |   <fld2>2</fld2>\n| &
          |   <fld3>3</fld3>\n| &
          |  </DD04V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zyyy.dtel.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD04V>\n| &
          |   <USEFULL>y</USEFULL>\n| &
          |   <fld1>1</fld1>\n| &
          |   <fld2>2</fld2>\n| &
          |   <fld3>3</fld3>\n| &
          |  </DD04V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zdoma.doma.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD01V>\n| &
          |   <USEFULL>doma</USEFULL>\n| &
          |   <xyz>xyz</xyz>\n| &
          |  </DD01V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zdoma2.doma.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD01V>\n| &
          |   <USEFULL>doma2</USEFULL>\n| &
          |  </DD01V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zdoma3.doma.extra.xml` data = cl_abap_codepage=>convert_to( source =
          |<SOMEDATA>\n| &
          | <USEFULL>doma3</USEFULL>\n| &
          |</SOMEDATA>\n| ) )
      )
    ).

    es_exp = value #(
      local = value #(
        ( file = value #( path = `` filename = `zyyy.dtel.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD04V>\n| &
          |   <USEFULL>y</USEFULL>\n| &
          |   <fld3>3</fld3>\n| &
          |  </DD04V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
          item = value #( obj_type = 'DTEL' obj_name = 'ZYYY' devclass = 'ZTMP' )
        )
      )
      remote = value #(
        ( path = `/` filename = `.xmlstrip.config` data = cl_abap_codepage=>convert_to( source =
          |remove DTEL:/dd04v/FLD1\n| &
          |remove DTEL:/dd04v/FLD2\n| &
          |remove DTEL(ZXXX):/dd04v/FLD3\n| &
          |remove DOMA:/DD01V/xyz\n| ) )
        ( path = `` filename = `zxxx.dtel.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD04V>\n| &
          |   <USEFULL>x</USEFULL>\n| &
          |  </DD04V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zyyy.dtel.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD04V>\n| &
          |   <USEFULL>y</USEFULL>\n| &
          |   <fld3>3</fld3>\n| &
          |  </DD04V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zdoma.doma.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD01V>\n| &
          |   <USEFULL>doma</USEFULL>\n| &
          |  </DD01V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zdoma2.doma.xml` data = cl_abap_codepage=>convert_to( source =
          |<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n| &
          | <asx:values>\n| &
          |  <DD01V>\n| &
          |   <USEFULL>doma2</USEFULL>\n| &
          |  </DD01V>\n| &
          | </asx:values>\n| &
          |</asx:abap>\n| ) )
        ( path = `` filename = `zdoma3.doma.extra.xml` data = cl_abap_codepage=>convert_to( source =
          |<SOMEDATA>\n| &
          | <USEFULL>doma3</USEFULL>\n| &
          |</SOMEDATA>\n| ) )
      )
    ).

  endmethod.

  method no_change_if_no_config.

    data ls_exp type ty_local_remote.
    data ls_input type ty_local_remote.

    prepare_mock(
      importing
        es_input = ls_input ).

    delete ls_input-remote where filename = '.xmlstrip.config'.
    ls_exp = ls_input.

    zcl_abapgit_xml_stripper=>process_files(
      changing
        ct_local  = ls_input-local
        ct_remote = ls_input-remote ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_input
      exp = ls_exp ).

  endmethod.

  method happy_path.

    data ls_exp   type ty_local_remote.
    data ls_input type ty_local_remote.
    data lv_equal type abap_bool.

    prepare_mock(
      importing
        es_input = ls_input
        es_exp   = ls_exp ).

    zcl_abapgit_xml_stripper=>process_files(
      changing
        ct_local  = ls_input-local
        ct_remote = ls_input-remote ).

    field-symbols <la> like line of ls_input-local.
    field-symbols <le> like line of ls_input-local.
    loop at ls_input-local assigning <la>.
      read table ls_exp-local with key file-filename = <la>-file-filename assigning <le>.
      cl_abap_unit_assert=>assert_subrc( ).
      cl_sxiveri_xml_comparator=>compare(
        exporting
          xml1      = <la>-file-data
          xml2      = <le>-file-data
        importing
          are_equal = lv_equal ).
      cl_abap_unit_assert=>assert_true( lv_equal ).
    endloop.

    field-symbols <ra> like line of ls_input-remote.
    field-symbols <re> like line of ls_input-remote.
    loop at ls_input-remote assigning <ra> where filename cp '*.xml'.
      read table ls_exp-remote with key filename = <ra>-filename assigning <re>.
      cl_abap_unit_assert=>assert_subrc( ).
      cl_sxiveri_xml_comparator=>compare(
        exporting
          xml1      = <ra>-data
          xml2      = <re>-data
        importing
          are_equal = lv_equal ).
      cl_abap_unit_assert=>assert_true( act = lv_equal msg = <ra>-filename ).
    endloop.

  endmethod.

endclass.