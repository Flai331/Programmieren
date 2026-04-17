"""PDF generation service using ReportLab with template overlay."""
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import black
from PyPDF2 import PdfReader, PdfWriter
import io
import os
from datetime import datetime
from typing import Optional


class PDFGenerator:
    """PDF generator that overlays invoice data on template PDFs."""

    def __init__(self, template_pdf_path: Optional[str] = None):
        """
        Initialize PDF generator.

        Args:
            template_pdf_path: Path to template PDF to use as background
        """
        self.template_pdf_path = template_pdf_path
        self.page_width, self.page_height = A4

    def generate_invoice_pdf(
        self,
        invoice_data: dict,
        customer_data: dict,
        items: list,
        template: dict,
        output_path: str,
    ) -> str:
        """
        Generate invoice PDF with template background.

        Args:
            invoice_data: Invoice information
            customer_data: Customer information
            items: List of invoice items
            template: Template configuration with positions
            output_path: Path where PDF should be saved

        Returns:
            Path to generated PDF
        """
        # Create a BytesIO buffer for the overlay
        buffer = io.BytesIO()

        # Create canvas for overlay
        c = canvas.Canvas(buffer, pagesize=A4)

        # Add invoice data to overlay
        self._add_invoice_header(c, invoice_data, template)
        self._add_customer_address(c, customer_data, template)
        self._add_invoice_items(c, items, template)
        self._add_totals(c, invoice_data, template)
        self._add_footer(c, template)

        c.save()

        # Merge overlay with template PDF if provided
        if self.template_pdf_path and os.path.exists(self.template_pdf_path):
            buffer.seek(0)
            overlay_pdf = PdfReader(buffer)
            template_pdf = PdfReader(self.template_pdf_path)

            writer = PdfWriter()

            # Merge first page
            template_page = template_pdf.pages[0]
            overlay_page = overlay_pdf.pages[0]
            template_page.merge_page(overlay_page)
            writer.add_page(template_page)

            # Write merged PDF
            with open(output_path, "wb") as output_file:
                writer.write(output_file)
        else:
            # No template, just use overlay
            with open(output_path, "wb") as output_file:
                output_file.write(buffer.getvalue())

        return output_path

    def _add_invoice_header(self, c: canvas.Canvas, invoice_data: dict, template: dict):
        """Add invoice number and date."""
        c.setFont("Helvetica-Bold", 12)

        # Invoice number
        x = template.get("invoice_number_x", 420)
        y = self.page_height - template.get("invoice_number_y", 150)
        c.drawString(x, y, f"Rechnungsnr.: {invoice_data['invoice_number']}")

        # Invoice date
        x = template.get("invoice_date_x", 420)
        y = self.page_height - template.get("invoice_date_y", 170)
        invoice_date = invoice_data["invoice_date"]
        if isinstance(invoice_date, str):
            date_str = invoice_date.split("T")[0]
        else:
            date_str = invoice_date.strftime("%d.%m.%Y")
        c.drawString(x, y, f"Datum: {date_str}")

        # Due date if available
        if invoice_data.get("due_date"):
            due_date = invoice_data["due_date"]
            if isinstance(due_date, str):
                due_date_str = due_date.split("T")[0]
            else:
                due_date_str = due_date.strftime("%d.%m.%Y")
            y -= 20
            c.drawString(x, y, f"Fällig: {due_date_str}")

    def _add_customer_address(self, c: canvas.Canvas, customer_data: dict, template: dict):
        """Add customer address."""
        c.setFont("Helvetica", 10)

        x = template.get("customer_address_x", 50)
        y = self.page_height - template.get("customer_address_y", 220)

        # Customer name
        if customer_data.get("company"):
            c.drawString(x, y, customer_data["company"])
            y -= 15
            c.drawString(x, y, customer_data["name"])
        else:
            c.drawString(x, y, customer_data["name"])

        # Address
        if customer_data.get("street"):
            y -= 15
            c.drawString(x, y, customer_data["street"])

        if customer_data.get("postal_code") and customer_data.get("city"):
            y -= 15
            c.drawString(x, y, f"{customer_data['postal_code']} {customer_data['city']}")

    def _add_invoice_items(self, c: canvas.Canvas, items: list, template: dict):
        """Add invoice items table."""
        x = template.get("items_start_x", 50)
        y = self.page_height - template.get("items_start_y", 350)
        line_height = template.get("items_line_height", 20)

        # Table headers
        c.setFont("Helvetica-Bold", 10)
        c.drawString(x, y, "Pos.")
        c.drawString(x + 40, y, "Beschreibung")
        c.drawString(x + 280, y, "Menge")
        c.drawString(x + 340, y, "Einheit")
        c.drawString(x + 400, y, "Einzelpreis")
        c.drawString(x + 480, y, "Gesamt")

        y -= line_height

        # Draw line under headers
        c.line(x, y + 5, x + 545, y + 5)

        y -= 5

        # Table content
        c.setFont("Helvetica", 9)
        for idx, item in enumerate(items, 1):
            y -= line_height

            c.drawString(x, y, str(idx))
            c.drawString(x + 40, y, item["description"][:40])  # Truncate long descriptions
            c.drawString(x + 280, y, f"{item['quantity']:.2f}")
            c.drawString(x + 340, y, item.get("unit", "Stück"))
            c.drawString(x + 400, y, f"{item['unit_price']:.2f} €")
            c.drawString(x + 480, y, f"{item['total']:.2f} €")

        return y

    def _add_totals(self, c: canvas.Canvas, invoice_data: dict, template: dict):
        """Add invoice totals."""
        x = template.get("items_start_x", 50) + 400
        y = self.page_height - template.get("items_start_y", 350) - (len(invoice_data.get("items", [])) + 4) * template.get("items_line_height", 20)

        y -= 40  # Extra space before totals

        c.setFont("Helvetica", 10)

        # Subtotal
        c.drawString(x, y, "Netto:")
        c.drawString(x + 80, y, f"{invoice_data['subtotal']:.2f} €")

        # Tax
        y -= 20
        tax_rate = invoice_data.get("tax_rate", 19.0)
        c.drawString(x, y, f"MwSt. ({tax_rate}%):")
        c.drawString(x + 80, y, f"{invoice_data['tax_amount']:.2f} €")

        # Total
        y -= 25
        c.setFont("Helvetica-Bold", 12)
        c.drawString(x, y, "Gesamt:")
        c.drawString(x + 80, y, f"{invoice_data['total']:.2f} €")

    def _add_footer(self, c: canvas.Canvas, template: dict):
        """Add footer with sender information and payment details."""
        c.setFont("Helvetica", 8)
        y = 80

        # Payment information if available
        if template.get("bank_name"):
            footer_text = f"Bank: {template['bank_name']}"
            if template.get("iban"):
                footer_text += f" | IBAN: {template['iban']}"
            if template.get("bic"):
                footer_text += f" | BIC: {template['bic']}"

            c.drawString(50, y, footer_text)
            y -= 15

        # Tax IDs
        if template.get("tax_id") or template.get("vat_id"):
            tax_info = []
            if template.get("tax_id"):
                tax_info.append(f"Steuernr.: {template['tax_id']}")
            if template.get("vat_id"):
                tax_info.append(f"USt-IdNr.: {template['vat_id']}")

            c.drawString(50, y, " | ".join(tax_info))
