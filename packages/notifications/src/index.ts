import nodemailer from 'nodemailer';

type OrderConfirmedPayload = { orderId: string; tenantId: string; toEmail?: string };

export async function notifyOrderConfirmed(payload: OrderConfirmedPayload): Promise<void> {
  const to = payload.toEmail || process.env.NOTIFY_TEST_EMAIL || '';
  if (!to) return; // noop in dev if no recipient configured
  const host = process.env.SMTP_HOST || 'localhost';
  const port = Number(process.env.SMTP_PORT || 1025);
  const user = process.env.SMTP_USER || '';
  const pass = process.env.SMTP_PASS || '';
  const from = process.env.SMTP_FROM || 'no-reply@thankful.local';
  const transport = nodemailer.createTransport({ host, port, secure: false, auth: user ? { user, pass } : undefined });
  await transport.sendMail({ from, to, subject: `Order confirmed: ${payload.orderId}`, text: `Order ${payload.orderId} confirmed for tenant ${payload.tenantId}` });
}


