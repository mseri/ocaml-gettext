
open LibraryGettext;;

(* Give access to the init of LibraryGettext *)
let init =
  Gettext.init
;;

(* Example function *)
let library_only_function () = 
  
  (* Two simple examples : singular translation *)
  print_endline (s_ "Hello world !");
  Printf.printf (f_ "Hello %s !\n") "world";
  
  (* More complicated : plural translation, using strings *)
  print_endline (
     (sn_ "There is " "There are " 2)
    ^(string_of_int 2)
    ^(sn_ "plate." "plates." 2)
  );
  
  (* More simple forms of plural translation, using printf *)
  Printf.printf (fn_ "There is %d plate.\n" "There are %d plates.\n" 2) 2
;;

(* Another example function : used by program.ml *)
let hello_you name =
  Printf.printf (f_ "Hello %s\n") name
;;
