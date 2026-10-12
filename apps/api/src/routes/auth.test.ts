import assert from "node:assert/strict";
import test from "node:test";
import { loginSchema, registerSchema } from "./auth.js";

test("registration trims identity fields and normalizes email", () => {
  const user = registerSchema.parse({
    Name: "  Ani Putri  ",
    Email: "  ANI@EXAMPLE.COM ",
    Nim: "  123456  ",
    Password: "secret1",
  });

  assert.equal(user.Name, "Ani Putri");
  assert.equal(user.Email, "ani@example.com");
  assert.equal(user.Nim, "123456");
});

test("login normalizes email and auth input enforces minimum requirements", () => {
  assert.equal(loginSchema.parse({ Email: " USER@EXAMPLE.COM ", Password: "x" }).Email, "user@example.com");
  const validUser = { Name: "Ani", Email: "ani@example.com", Nim: "123", Password: "secret1" };

  assert.equal(registerSchema.safeParse({ ...validUser, Name: " " }).success, false);
  assert.equal(registerSchema.safeParse({ ...validUser, Email: "not-an-email" }).success, false);
  assert.equal(registerSchema.safeParse({ ...validUser, Nim: "12" }).success, false);
  assert.equal(registerSchema.safeParse({ ...validUser, Password: "12345" }).success, false);
  assert.equal(loginSchema.safeParse({ Email: "invalid", Password: "x" }).success, false);
});