'use strict';

const nodemailer = require('nodemailer');

function createTransport() {
  if (process.env.MAIL_HOST) {
    return nodemailer.createTransport({
      host: process.env.MAIL_HOST,
      port: parseInt(process.env.MAIL_PORT, 10) || 587,
      secure: process.env.MAIL_SECURE === 'true',
      auth: {
        user: process.env.MAIL_USER,
        pass: process.env.MAIL_PASS,
      },
    });
  }
  return null;
}

async function sendPasswordReset(toEmail, userName, resetUrl) {
  const transport = createTransport();

  // Development fallback — log to console when no SMTP is configured
  if (!transport) {
    console.log('\n─── [DEV] Password Reset Email ─────────────────────');
    console.log(`  To:   ${toEmail}`);
    console.log(`  Link: ${resetUrl}`);
    console.log('────────────────────────────────────────────────────\n');
    return;
  }

  await transport.sendMail({
    from: process.env.MAIL_FROM || '"GaspZero" <no-reply@gaspzero.com>',
    to: toEmail,
    subject: 'Reset your GaspZero password',
    text: `Hi ${userName},\n\nYou requested a password reset. Click the link below (valid for 1 hour):\n\n${resetUrl}\n\nIf you did not request this, ignore this email.`,
    html: `
      <p>Hi <strong>${userName}</strong>,</p>
      <p>You requested a password reset. Click the button below — the link is valid for <strong>1 hour</strong>.</p>
      <p style="margin:24px 0">
        <a href="${resetUrl}" style="background:#22c55e;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:bold">
          Reset Password
        </a>
      </p>
      <p>Or copy this link: <a href="${resetUrl}">${resetUrl}</a></p>
      <p style="color:#888;font-size:12px">If you did not request this, you can safely ignore this email.</p>
    `,
  });
}

module.exports = { sendPasswordReset };
