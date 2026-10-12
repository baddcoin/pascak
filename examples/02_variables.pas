// Tipe data & operator dasar
begin
  // Inferred type
  var nama := "Alice";
  var umur := 30;
  var tinggi := 165.5;
  var aktif := true;
  var kosong := null;
  
  println("Nama: ", nama);
  println("Umur: ", umur, " tahun");
  println("Tinggi: ", tinggi, " cm");
  println("Aktif: ", aktif);
  println("Kosong: ", kosong);
  
  // Aritmatika
  var a := 10;
  var b := 3;
  println(a, " + ", b, " = ", a + b);
  println(a, " - ", b, " = ", a - b);
  println(a, " * ", b, " = ", a * b);
  println(a, " / ", b, " = ", a / b);
  println(a, " mod ", b, " = ", a mod b);
  
  // Compound assignment
  var counter := 0;
  counter += 5;
  counter *= 2;
  println("Counter: ", counter);
  
  // Type conversion
  var s := "42";
  var n := toInteger(s);
  println("Converted: ", n + 8);
end.