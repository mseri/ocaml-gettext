
open GettextTypes;;
open FileUtil.StrUtil;;

(** filename wich generates the error message str *)
exception ProblemReadingFile of filename * string;;
(** while extracting filename the command str returns exit code i *)
exception ExtractionFailed of filename * string * int;;
(** while extracting filename the command receive signal i *)
exception ExtractionInterrupted of filename * string * int;;

let string_of_exception exc = 
  match exc with
    ProblemReadingFile(fln,error) ->
      "Problem reading file "^fln^" : "^error
  | ExtractionFailed(fln,cmd,status) ->
      "Problem while extracting "^fln^" : command "^cmd^" exits with code "^(string_of_int status)
  | ExtractionInterrupted(fln,cmd,signal) ->
      "Problem while extracting "^fln^" : command "^cmd^" killed by signal "^(string_of_int signal)
  | _ ->
      raise exc
;;

(** extract cmd default_option file_options src_files ppf : extract the
    translatable strings from all the src_files provided. Each source file will 
    be extracted using the command cmd, which should be an executable that has
    the same output as ocaml-xgettext. If cmd is not provided, it will be
    searched in the current path. The command will be called with
    default_option, or if the file being extracted is mapped in file_options,
    with the option associated to the filename in file_options. The result will
    be written using module Format to the formatter ppf. The result of the
    extraction should be used as a po template file.
  *)
let po_of_filename filename = 
  let chn = 
    try
      open_in filename
    with Sys_error(str) ->
      raise (ProblemReadingFile(filename,str))
  in
  let po = 
    GettextPo.input_po chn
  in
  close_in chn;
  po
;;

let extract command default_options filename_options filename_lst filename_pot =
  let make_command options filename = 
    command^" "^options^" "^filename
  in
  let extract_one po filename =
    let options = 
      try
        MapString.find filename filename_options 
      with Not_found ->
        default_options
    in
    let real_command = 
      make_command options filename
    in
    let chn = 
      Unix.open_process_in real_command
    in 
    let value = 
      (Marshal.from_channel chn : po_content) 
    in
    match Unix.close_process_in chn with
    | Unix.WEXITED 0 ->
        GettextPo.merge_po po value
    | Unix.WEXITED exit_code -> 
        raise (ExtractionFailed(filename,real_command,exit_code))
    | Unix.WSIGNALED signal
    | Unix.WSTOPPED signal -> 
        raise (ExtractionInterrupted(filename,real_command,signal))
  in
  let extraction = 
    List.fold_left extract_one GettextPo.empty_po filename_lst
  in
  let chn = 
    open_out filename_pot
  in
  Printf.fprintf chn "%s" 
"# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
#, fuzzy
msgid \"\"
msgstr \"\"
\"Project-Id-Version: PACKAGE VERSION\\n\"
\"Report-Msgid-Bugs-To: \\n\"
\"POT-Creation-Date: 2005-02-02 00:35+0100\\n\"
\"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n\"
\"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n\"
\"Language-Team: LANGUAGE <LL@li.org>\\n\"
\"MIME-Version: 1.0\\n\"
\"Content-Type: text/plain; charset=CHARSET\\n\"
\"Content-Transfer-Encoding: 8bit\\n\"
\"Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\\n\"

";
  GettextPo.output_po chn extraction;
  close_out chn
;;

(** compile *)
let compile filename_po filename_mo =
  let po = 
    po_of_filename filename_po
  in
  let output_one_map filename map = 
    let lst = 
      MapString.fold ( fun _ (_,e) lst -> e :: lst ) map []
    in
    let chn = 
      open_out_bin filename
    in
    GettextMo.output_mo chn lst;
    close_out chn
  in
  output_one_map filename_mo po.no_domain;
  MapTextdomain.iter ( 
    fun domain map -> 
      output_one_map (domain^"."^filename_mo) map 
    ) po.domain
;;

let install destdir language category textdomain filename_mo_src =
  let filename_mo_dst = 
    GettextDomain.make_filename destdir language category textdomain
  in
  cp [filename_mo_src] filename_mo_dst
;;

(*let merge filename_pot filename_po_lst backup_extension =
  let pot = 
    po_of_filename filename_pot
  in
  let merge_one filename_po =
    let po = 
      po_of_filename filename_po
    in
    let _ = 
      (* BUG: should use add_extension *)
      mv filename_po (filename_po^"."^backup_extension)
    in
    
      
;;*)
