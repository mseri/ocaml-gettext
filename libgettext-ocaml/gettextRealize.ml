(** Module type for the function realize *)

open GettextTypes;;
open GettextUtils;;

module type REALIZE_TYPE =
  sig
    val realize : realize
  end
;;

module Generic : (
    functor ( Translate : GettextTranslate.TRANSLATE_TYPE ) ->
    functor ( Charset : GettextCharset.CHARSET_TYPE ) ->
    functor ( Locale : GettextLocale.LOCALE_TYPE ) ->  REALIZE_TYPE ) =
  functor ( Translate : GettextTranslate.TRANSLATE_TYPE ) ->
  functor ( Charset : GettextCharset.CHARSET_TYPE ) ->
  functor ( Locale : GettextLocale.LOCALE_TYPE ) -> 
  struct

    module MapTranslate = Map.Make(struct
      type t = textdomain * category
      let compare (t1,c1) (t2,c2) = 
        match String.compare t1 t2 with
          0 -> GettextCategory.compare c1 c2
        | x -> x
    end)

    let add_textdomain_category t map_translate textdomain category =
      try
        let filename = 
          GettextDomain.find 
          t 
          (fst (Locale.get_locale t category)) 
          category 
          textdomain
        in
        let in_enc =
          let chn = open_in_bin filename
          in
          let mo_header = GettextMo.input_mo_header chn
          in
          let mo_informations = GettextMo.input_mo_informations t.failsafe chn mo_header
          in
          mo_informations.content_type_charset
        in
        let out_enc = 
          try
            match (MapTextdomain.find textdomain t.textdomains) with
              (Some codeset, _) -> codeset
            | (None, _) -> snd (Locale.get_locale t category)
          with Not_found ->
            snd (Locale.get_locale t category)
        in
        let recode =
          Charset.recode (Charset.create t in_enc out_enc) 
        in
        MapTranslate.add 
          (textdomain,category) 
          (Translate.create t filename recode) 
          map_translate
      with GettextDomain.DomainFileDoesntExist(filenames) as exc ->
        map_translate

    let add_textdomain t map_translate textdomain =
      List.fold_left (
        fun m category -> 
          add_textdomain_category t m textdomain category
      ) map_translate GettextCategory.categories

    let realize t = 
      let map_translate = 
        MapTextdomain.fold ( 
          fun textdomain _ m -> 
            add_textdomain t m textdomain 
        ) t.textdomains MapTranslate.empty 
      in
      let dummy_translate =
        GettextTranslate.Dummy.create t "(none)" ( fun s -> s ) 
      in
      fun opt str plural_form category ->
        (
          let textdomain = 
            match opt with
              Some textdomain -> textdomain
            | None -> t.default
          in
          try 
            Translate.translate (
              MapTranslate.find (textdomain,category) map_translate
            ) str plural_form 
          with Not_found ->
            GettextTranslate.Dummy.translate 
            dummy_translate
            str plural_form
        )
  end 
;;
      
