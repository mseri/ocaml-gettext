(** Signature of module for translation storage / access *)

open GettextTypes;;
open GettextUtils;;
open GettextMo;;

module type TRANSLATE_TYPE =
  functor ( Charset : GettextCharset.CHARSET_TYPE ) ->
  sig
    type t

    (** create chn charset : Create a translation table using chn as 
        the file descriptor for a mo file and charset as the charset 
        transcoder. If chn is closed, any subsequent action could
        failed ( ie, if the asked elements is cached, it could not 
        failed, for example ).
    *)
    val create : failsafe -> in_channel -> Charset.t -> t

    (** translate str (plural_form,number) tbl : translate the string 
        str using tbl. It is possible that the operation modify tbl, 
        so it is returned also. It is also possible to get the plural 
        form of the translated string using plural_form and number.
    *)
    val translate : 
         string 
      -> ?plural_form: (string * int)
      -> t 
      -> translated_type option * t
  end
;;

module Dummy : TRANSLATE_TYPE =
  functor ( Charset : GettextCharset.CHARSET_TYPE ) ->
  struct
    type t = Charset.t

    let create failsafe chn charset = charset

    let translate str ?plural_form charset = 
      match plural_form with
        None 
      | Some(_,0) ->
          ( Some (Singular(str,Charset.recode str charset)), charset )
      | Some(str_plural,_) ->
          ( Some(Plural
            (
              str,str_plural,
              [Charset.recode str charset ; Charset.recode str_plural charset]
            )), 
            charset
          )
  end
;;

module Map : TRANSLATE_TYPE =
  functor ( Charset : GettextCharset.CHARSET_TYPE ) ->
  struct
    type t = {
      failsafe  : failsafe;
      charset   : Charset.t;
      mo_header : mo_header_type;
      chn       : in_channel;
      map       : translated_type MapString.t;
      last      : int;
    }

    let create failsafe chn charset = {
      failsafe  = failsafe;
      charset   = charset;
      mo_header = input_mo_header chn;
      chn       = chn;
      map       = MapString.empty;
      last      = 0;
    }

    let rec translate str ?plural_form mp = 
      try 
        let new_translation = MapString.find str mp.map
        in
        (Some new_translation, mp)
      with Not_found ->
        if mp.last < Int32.to_int mp.mo_header.number_of_strings then
          let new_translation = 
            input_mo_translation mp.failsafe mp.chn mp.mo_header (mp.last + 1)
          in
          let new_map =
            match new_translation with
              Singular(id,str) ->
                MapString.add 
                id 
                (Singular(id,Charset.recode str mp.charset)) 
                mp.map
            | Plural(id,id_plural,lst) ->
                MapString.add
                id
                (Plural(id,id_plural,
                List.map (fun x -> Charset.recode x mp.charset) lst))
                mp.map
          in
          let new_mp = 
            {
              failsafe  = mp.failsafe;
              charset   = mp.charset;
              mo_header = mp.mo_header;
              chn       = mp.chn;
              map       = new_map;
              last      = mp.last + 1;
            }
          in
          (* DEBUG *) print_endline ( "Comparing \""
            ^str
            ^"\" with \""
            ^(match new_translation with Singular(id,_) | Plural(id,_,_) -> id )
            ^"\"");
          match new_translation with
            Singular(id,_) when id = str ->
              (Some new_translation,new_mp)
          | Plural(id,_,_) when id = str ->
              (Some new_translation,new_mp)
          | _ ->
              (
                match plural_form with
                  Some x ->
                    translate str ~plural_form:x new_mp
                | None ->
                    translate str new_mp
              )
        else
          (* BUG : on ne retient pas la mémorisation des chaines parcourue
          * pendant la recherche *)
          (None, mp)
            
  end
;;
