import { supabase } from './supabase';

// Kiểm tra kết nối Supabase
function getSupabase() {
  if (!supabase) {
    throw new Error(
      'Supabase chưa được cấu hình. Vui lòng kiểm tra file .env'
    );
  }

  return supabase;
}

// ĐĂNG KÝ KHÁCH HÀNG BẰNG GMAIL
export async function registerCustomer(
  email: string,
  password: string
) {
  const client = getSupabase();

  const normalizedEmail = email.trim().toLowerCase();

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
    throw new Error('Vui lòng nhập Gmail hợp lệ.');
  }

if (password.length < 8) {
  throw new Error('Mật khẩu phải có ít nhất 8 ký tự.');
}

  const { data, error } = await client.auth.signUp({
    email: normalizedEmail,
    password,
  });

  if (error) throw error;

  if (!data.session) {
    const { data: loginData, error: loginError } =
      await client.auth.signInWithPassword({
        email: normalizedEmail,
        password,
      });

    if (loginError) throw loginError;

    return loginData;
  }

  return data;
}

// ĐĂNG NHẬP KHÁCH HÀNG BẰNG GMAIL
export async function loginCustomer(
  email: string,
  password: string
) {
  const client = getSupabase();

  const normalizedEmail = email.trim().toLowerCase();

  const { data, error } = await client.auth.signInWithPassword({
    email: normalizedEmail,
    password,
  });

  if (error) throw error;

  return data;
}