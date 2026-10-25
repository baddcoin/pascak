// examples/lang_v110.pas
// Pascak v1.1.0 language features showcase:
// optional chaining (?.), null-coalescing (??), enum, destructuring.

// Top-level enum
enum Priority { Low, Medium, High }

// Top-level destructuring
var {app_name, ver_tag} = {"app_name": "Pascak Demo", "ver_tag": "v1.1.0"};

begin
  println("=== App ===");
  println("Name: ", app_name);
  println("Version: ", ver_tag);

  println("");
  println("=== Optional Chaining ===");
  var u1 := {"name": "Alice", "email": "alice@example.com"};
  var u2 := {"name": "Bob"};
  var n := null;

  println("u1?.name  = ", u1?.name);
  println("u2?.email = ", u2?.email);
  println("n?.name   = ", n?.name);

  println("");
  println("=== Null-Coalescing ===");
  println("null ?? 'default'  = ", null ?? "default");
  println("0 ?? 42            = ", 0 ?? 42);
  println("false ?? 42        = ", false ?? 42);
  println("u2?.email ?? '-'   = ", u2?.email ?? "-");

  println("");
  println("=== Enum ===");
  println("Priority.Low    = ", Priority.Low);
  println("Priority.Medium = ", Priority.Medium);
  println("Priority.High   = ", Priority.High);

  var p := Priority.High;
  println("Assigned p      = ", p);

  println("");
  println("=== Destructuring (statement scope) ===");
  var {host, port} = {"host": "localhost", "port": 8080};
  println("Host: ", host);
  println("Port: ", port);

  var [a, b, c] = [10, 20, 30];
  println("a+b+c = ", a + b + c);

  println("");
  println("=== Combined Patterns ===");
  var cfg := {"db": null};
  var db_host := cfg?.db?.host ?? "localhost";
  println("cfg?.db?.host ?? 'localhost' = ", db_host);

  var cfg2 := {"db": {"host": "prod.example.com"}};
  var prod_host := cfg2?.db?.host ?? "localhost";
  println("full path                    = ", prod_host);
end.
