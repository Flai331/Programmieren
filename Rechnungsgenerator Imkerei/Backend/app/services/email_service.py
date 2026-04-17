"""Email service for sending invoices."""
import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from typing import Optional, List
from pydantic import BaseModel, EmailStr

from ..config import settings


class EmailConfig(BaseModel):
    """Email configuration."""
    smtp_server: str = "smtp.gmail.com"
    smtp_port: int = 587
    username: str
    password: str  # App-specific password for Gmail
    from_email: str
    from_name: str = "Rechnungsgenerator Imkerei"


class EmailMessage(BaseModel):
    """Email message structure."""
    to_email: EmailStr
    subject: str
    body: str
    body_html: Optional[str] = None
    attachments: Optional[List[str]] = None  # List of file paths


class EmailService:
    """Service for sending emails with attachments."""

    def __init__(self, config: EmailConfig):
        self.config = config

    def send_email(self, message: EmailMessage) -> bool:
        """
        Send an email with optional attachments.

        Args:
            message: Email message with recipient, subject, body, and attachments

        Returns:
            True if email was sent successfully
        """
        try:
            # Create message
            msg = MIMEMultipart('alternative')
            msg['From'] = f"{self.config.from_name} <{self.config.from_email}>"
            msg['To'] = message.to_email
            msg['Subject'] = message.subject

            # Add plain text body
            msg.attach(MIMEText(message.body, 'plain'))

            # Add HTML body if provided
            if message.body_html:
                msg.attach(MIMEText(message.body_html, 'html'))

            # Add attachments
            if message.attachments:
                for file_path in message.attachments:
                    if os.path.exists(file_path):
                        self._attach_file(msg, file_path)

            # Send email
            with smtplib.SMTP(self.config.smtp_server, self.config.smtp_port) as server:
                server.starttls()
                server.login(self.config.username, self.config.password)
                server.send_message(msg)

            return True

        except Exception as e:
            print(f"Fehler beim E-Mail-Versand: {e}")
            return False

    def _attach_file(self, msg: MIMEMultipart, file_path: str):
        """Attach a file to the email message."""
        filename = os.path.basename(file_path)

        with open(file_path, 'rb') as attachment:
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(attachment.read())

        encoders.encode_base64(part)
        part.add_header(
            'Content-Disposition',
            f'attachment; filename= {filename}'
        )
        msg.attach(part)

    def send_invoice(
        self,
        to_email: str,
        customer_name: str,
        invoice_number: str,
        pdf_path: str,
        custom_message: Optional[str] = None
    ) -> bool:
        """
        Send an invoice via email.

        Args:
            to_email: Recipient email address
            customer_name: Customer name for personalization
            invoice_number: Invoice number for subject
            pdf_path: Path to the PDF file
            custom_message: Optional custom message

        Returns:
            True if email was sent successfully
        """
        subject = f"Rechnung {invoice_number}"

        body = f"""Sehr geehrte(r) {customer_name},

anbei erhalten Sie die Rechnung {invoice_number}.

{custom_message if custom_message else ''}

Bei Fragen stehen wir Ihnen gerne zur Verfügung.

Mit freundlichen Grüßen
{self.config.from_name}
"""

        body_html = f"""
<html>
<body>
<p>Sehr geehrte(r) {customer_name},</p>

<p>anbei erhalten Sie die Rechnung <strong>{invoice_number}</strong>.</p>

{f'<p>{custom_message}</p>' if custom_message else ''}

<p>Bei Fragen stehen wir Ihnen gerne zur Verfügung.</p>

<p>Mit freundlichen Grüßen<br>
<strong>{self.config.from_name}</strong></p>
</body>
</html>
"""

        message = EmailMessage(
            to_email=to_email,
            subject=subject,
            body=body,
            body_html=body_html,
            attachments=[pdf_path] if pdf_path and os.path.exists(pdf_path) else None
        )

        return self.send_email(message)


# Singleton instance (wird bei Bedarf initialisiert)
_email_service: Optional[EmailService] = None


def get_email_service() -> Optional[EmailService]:
    """Get the email service instance."""
    global _email_service

    # Check if email is configured
    smtp_user = os.getenv('SMTP_USERNAME')
    smtp_pass = os.getenv('SMTP_PASSWORD')

    if not smtp_user or not smtp_pass:
        return None

    if _email_service is None:
        config = EmailConfig(
            smtp_server=os.getenv('SMTP_SERVER', 'smtp.gmail.com'),
            smtp_port=int(os.getenv('SMTP_PORT', '587')),
            username=smtp_user,
            password=smtp_pass,
            from_email=os.getenv('SMTP_FROM_EMAIL', smtp_user),
            from_name=os.getenv('SMTP_FROM_NAME', 'Rechnungsgenerator Imkerei')
        )
        _email_service = EmailService(config)

    return _email_service
