// Contoh dasar FFI: panggil libc strlen
begin
  println("=== Hello FFI ===");
  
  var lib := dll.load("libpascak_ffi_test.so");
  
  // Signature: char* → int64
  var strlenFn := lib.func("pascak_strlen", "s->i");
  
  println("strlen('hello') = ", strlenFn("hello"));
  println("strlen('pascak') = ", strlenFn("pascak"));
  
  lib.close();
end.