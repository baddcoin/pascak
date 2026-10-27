// examples/lang_v125.pas
// Pascak v1.2.5: object rest destructuring + dict.omit

begin
  println("=== Basic Object Rest ===");
  var {name, age, ...others} =
    {"name": "Alice", "age": 30, "email": "a@x.com", "role": "admin"};
  println("name         = ", name);
  println("age          = ", age);
  println("others.email = ", others.email);
  println("others.role  = ", others.role);

  println("");
  println("=== Only Rest (Clone) ===");
  var {...clone} = {"x": 1, "y": 2};
  println("clone.x = ", clone.x);
  println("clone.y = ", clone.y);

  println("");
  println("=== Config Pattern ===");
  var {api_key, ...public_cfg} =
    {"api_key": "secret123", "host": "prod.example.com", "port": 443};
  println("host = ", public_cfg.host);
  println("port = ", public_cfg.port);
  // public_cfg.api_key already omitted

  println("");
  println("=== Nested + Rest ===");
  var {db: {host}, ...app_cfg} =
    {"db": {"host": "localhost", "user": "root"}, "debug": true, "ver": "1.0"};
  println("db host       = ", host);
  println("app_cfg.debug = ", app_cfg.debug);
  println("app_cfg.ver   = ", app_cfg.ver);

  println("");
  println("=== dict.omit Standalone ===");
  var full := {"a": 1, "b": 2, "c": 3, "secret": 99};
  var safe := full.omit(["secret"]);
  println("safe.a = ", safe.a);
  println("safe.b = ", safe.b);
  println("safe.c = ", safe.c);
end.
