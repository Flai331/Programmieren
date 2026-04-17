/**
 * Rechnungsgenerator Imkerei - Desktop App
 * Main Application JavaScript
 */

// API Configuration
const API_BASE_URL = 'http://localhost:8000/api';

// Application State
const AppState = {
    token: null,
    user: null,
    customers: [],
    invoices: [],
    articles: [],
    currentPage: 'login'
};

// ============================================
// API Client
// ============================================

const api = {
    async request(endpoint, options = {}) {
        const url = `${API_BASE_URL}${endpoint}`;
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };

        if (AppState.token) {
            headers['Authorization'] = `Bearer ${AppState.token}`;
        }

        try {
            const response = await fetch(url, {
                ...options,
                headers
            });

            if (response.status === 401) {
                logout();
                throw new Error('Sitzung abgelaufen');
            }

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || 'Ein Fehler ist aufgetreten');
            }

            return await response.json();
        } catch (error) {
            if (error.message === 'Failed to fetch') {
                updateConnectionStatus(false);
                throw new Error('Keine Verbindung zum Server');
            }
            throw error;
        }
    },

    get(endpoint) {
        return this.request(endpoint, { method: 'GET' });
    },

    post(endpoint, data) {
        return this.request(endpoint, {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    put(endpoint, data) {
        return this.request(endpoint, {
            method: 'PUT',
            body: JSON.stringify(data)
        });
    },

    delete(endpoint) {
        return this.request(endpoint, { method: 'DELETE' });
    },

    async login(username, password) {
        const formData = new URLSearchParams();
        formData.append('username', username);
        formData.append('password', password);

        const response = await fetch(`${API_BASE_URL}/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: formData
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Login fehlgeschlagen');
        }

        return await response.json();
    }
};

// ============================================
// Authentication
// ============================================

async function handleLogin(event) {
    event.preventDefault();

    const username = document.getElementById('loginUsername').value;
    const password = document.getElementById('loginPassword').value;
    const errorElement = document.getElementById('loginError');
    const submitButton = event.target.querySelector('button[type="submit"]');

    errorElement.style.display = 'none';
    submitButton.disabled = true;
    submitButton.textContent = 'Anmelden...';

    try {
        const data = await api.login(username, password);
        AppState.token = data.access_token;
        localStorage.setItem('token', AppState.token);

        AppState.user = await api.get('/auth/me');
        updateConnectionStatus(true);
        showApp();
        showToast('Erfolgreich angemeldet', 'success');
        loadDashboardData();
    } catch (error) {
        errorElement.textContent = error.message;
        errorElement.style.display = 'block';
    } finally {
        submitButton.disabled = false;
        submitButton.textContent = 'Anmelden';
    }
}

async function handleRegister(event) {
    event.preventDefault();

    const username = document.getElementById('regUsername').value;
    const email = document.getElementById('regEmail').value;
    const fullName = document.getElementById('regFullName').value;
    const password = document.getElementById('regPassword').value;
    const errorElement = document.getElementById('registerError');
    const submitButton = event.target.querySelector('button[type="submit"]');

    errorElement.style.display = 'none';
    submitButton.disabled = true;
    submitButton.textContent = 'Registrieren...';

    try {
        await api.post('/auth/register', {
            username,
            email,
            full_name: fullName,
            password
        });

        showToast('Registrierung erfolgreich! Bitte melden Sie sich an.', 'success');
        showLoginForm();
    } catch (error) {
        errorElement.textContent = error.message;
        errorElement.style.display = 'block';
    } finally {
        submitButton.disabled = false;
        submitButton.textContent = 'Registrieren';
    }
}

function logout() {
    AppState.token = null;
    AppState.user = null;
    localStorage.removeItem('token');
    showLogin();
    showToast('Abgemeldet', 'info');
}

function showLoginForm() {
    document.querySelector('.login-box').style.display = 'block';
    document.getElementById('registerBox').style.display = 'none';
}

function showRegisterForm() {
    document.querySelector('.login-box').style.display = 'none';
    document.getElementById('registerBox').style.display = 'block';
}

// ============================================
// Navigation
// ============================================

function showLogin() {
    document.querySelector('.sidebar').style.display = 'none';
    document.querySelector('.main-content').style.marginLeft = '0';
    document.getElementById('btnLogout').style.display = 'none';
    hideAllPages();
    document.getElementById('page-login').classList.add('active');
}

function showApp() {
    document.querySelector('.sidebar').style.display = 'flex';
    document.querySelector('.main-content').style.marginLeft = 'var(--sidebar-width)';
    document.getElementById('page-login').classList.remove('active');
    document.getElementById('btnLogout').style.display = 'block';

    if (AppState.user) {
        document.getElementById('userName').textContent = AppState.user.full_name || AppState.user.username;
    }

    showPage('dashboard');
}

function hideAllPages() {
    document.querySelectorAll('.page').forEach(page => {
        page.classList.remove('active');
    });
}

function showPage(pageId) {
    hideAllPages();

    // Update nav items
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
        if (item.dataset.page === pageId) {
            item.classList.add('active');
        }
    });

    // Show selected page
    const page = document.getElementById(`page-${pageId}`);
    if (page) {
        page.classList.add('active');
    }

    AppState.currentPage = pageId;

    // Load page data
    switch (pageId) {
        case 'dashboard':
            loadDashboardData();
            break;
        case 'invoices':
            loadInvoices();
            break;
        case 'customers':
            loadCustomers();
            break;
        case 'articles':
            loadArticles();
            break;
    }
}

// ============================================
// Dashboard
// ============================================

async function loadDashboardData() {
    try {
        const stats = await api.get('/statistics/overview');
        document.getElementById('statInvoices').textContent = stats.total_invoices || 0;
        document.getElementById('statCustomers').textContent = stats.total_customers || 0;
        document.getElementById('statRevenue').textContent = formatCurrency(stats.total_revenue || 0);
        document.getElementById('statPending').textContent = formatCurrency(stats.pending_amount || 0);
    } catch (error) {
        console.error('Dashboard data error:', error);
    }
}

// ============================================
// Invoices
// ============================================

async function loadInvoices() {
    const tableBody = document.getElementById('invoicesTableBody');
    tableBody.innerHTML = '<tr><td colspan="6" class="loading">Lade Rechnungen...</td></tr>';

    try {
        AppState.invoices = await api.get('/invoices');
        renderInvoicesTable();
    } catch (error) {
        tableBody.innerHTML = `<tr><td colspan="6" class="loading">Fehler: ${error.message}</td></tr>`;
    }
}

function renderInvoicesTable() {
    const tableBody = document.getElementById('invoicesTableBody');

    if (AppState.invoices.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="6" class="loading">Keine Rechnungen vorhanden</td></tr>';
        return;
    }

    tableBody.innerHTML = AppState.invoices.map(invoice => `
        <tr>
            <td>${invoice.invoice_number}</td>
            <td>${invoice.customer?.name || '-'}</td>
            <td>${formatDate(invoice.invoice_date)}</td>
            <td>${formatCurrency(invoice.total_amount)}</td>
            <td><span class="status-badge status-${invoice.status}">${getStatusText(invoice.status)}</span></td>
            <td>
                <button class="btn btn-sm btn-secondary" onclick="viewInvoice(${invoice.id})">Ansehen</button>
                <button class="btn btn-sm btn-primary" onclick="downloadInvoicePDF(${invoice.id})">PDF</button>
                <button class="btn btn-sm btn-success" onclick="sendInvoiceEmail(${invoice.id})">E-Mail</button>
            </td>
        </tr>
    `).join('');
}

function createNewInvoice() {
    const modalContent = `
        <form id="invoiceForm">
            <div class="form-group">
                <label for="invoiceCustomer">Kunde</label>
                <select id="invoiceCustomer" required>
                    <option value="">Kunde auswählen...</option>
                    ${AppState.customers.map(c => `<option value="${c.id}">${c.name}</option>`).join('')}
                </select>
            </div>
            <div class="form-group">
                <label for="invoiceDate">Rechnungsdatum</label>
                <input type="date" id="invoiceDate" value="${new Date().toISOString().split('T')[0]}" required>
            </div>
            <div class="form-group">
                <label for="invoiceDueDate">Fälligkeitsdatum</label>
                <input type="date" id="invoiceDueDate" required>
            </div>
            <div class="form-group">
                <label>Positionen</label>
                <div id="invoiceItems"></div>
                <button type="button" class="btn btn-secondary btn-sm" onclick="addInvoiceItem()">+ Position</button>
            </div>
            <div class="form-group">
                <label for="invoiceNotes">Notizen</label>
                <textarea id="invoiceNotes" rows="3"></textarea>
            </div>
            <div style="text-align: right; margin-top: 15px; font-weight: bold;">
                Gesamt: <span id="invoiceTotalDisplay">0,00 €</span>
            </div>
            <div style="margin-top: 20px; text-align: right;">
                <button type="button" class="btn btn-secondary" onclick="closeModal()">Abbrechen</button>
                <button type="submit" class="btn btn-primary">Speichern</button>
            </div>
        </form>
    `;

    showModal('Neue Rechnung', modalContent);

    // Set default due date (14 days from now)
    const dueDate = new Date();
    dueDate.setDate(dueDate.getDate() + 14);
    document.getElementById('invoiceDueDate').value = dueDate.toISOString().split('T')[0];

    // Add first item row
    addInvoiceItem();

    // Attach form submit handler
    document.getElementById('invoiceForm').addEventListener('submit', handleInvoiceSubmit);
}

function addInvoiceItem() {
    const container = document.getElementById('invoiceItems');
    const itemDiv = document.createElement('div');
    itemDiv.className = 'invoice-item';
    itemDiv.style.cssText = 'display: flex; gap: 10px; margin-bottom: 10px; align-items: center;';
    itemDiv.innerHTML = `
        <select class="item-article" style="flex: 2;" onchange="updateItemFromArticle(this)">
            <option value="">Artikel...</option>
            ${AppState.articles.map(a => `<option value="${a.id}" data-price="${a.price}">${a.name}</option>`).join('')}
        </select>
        <input type="text" class="item-description" placeholder="Beschreibung" style="flex: 3;">
        <input type="number" class="item-quantity" placeholder="Menge" value="1" min="1" style="width: 70px;" onchange="calculateItemTotal(this)">
        <input type="number" class="item-price" placeholder="Preis" step="0.01" style="width: 80px;" onchange="calculateItemTotal(this)">
        <span class="item-total" style="width: 80px; text-align: right;">0,00 €</span>
        <button type="button" class="btn btn-danger btn-sm" onclick="removeInvoiceItem(this)" style="padding: 5px 10px;">×</button>
    `;
    container.appendChild(itemDiv);
}

function updateItemFromArticle(select) {
    const itemDiv = select.closest('.invoice-item');
    const article = AppState.articles.find(a => a.id == select.value);

    if (article) {
        itemDiv.querySelector('.item-description').value = article.description || article.name;
        itemDiv.querySelector('.item-price').value = article.price;
        calculateItemTotal(itemDiv.querySelector('.item-quantity'));
    }
}

function calculateItemTotal(input) {
    const itemDiv = input.closest('.invoice-item');
    const quantity = parseFloat(itemDiv.querySelector('.item-quantity').value) || 0;
    const price = parseFloat(itemDiv.querySelector('.item-price').value) || 0;
    const total = quantity * price;
    itemDiv.querySelector('.item-total').textContent = formatCurrency(total);
    calculateInvoiceTotal();
}

function calculateInvoiceTotal() {
    const items = document.querySelectorAll('.invoice-item');
    let total = 0;
    items.forEach(item => {
        const quantity = parseFloat(item.querySelector('.item-quantity').value) || 0;
        const price = parseFloat(item.querySelector('.item-price').value) || 0;
        total += quantity * price;
    });
    document.getElementById('invoiceTotalDisplay').textContent = formatCurrency(total);
}

function removeInvoiceItem(button) {
    const container = document.getElementById('invoiceItems');
    if (container.children.length > 1) {
        button.closest('.invoice-item').remove();
        calculateInvoiceTotal();
    }
}

async function handleInvoiceSubmit(event) {
    event.preventDefault();

    const items = [];
    document.querySelectorAll('.invoice-item').forEach(itemDiv => {
        const articleId = itemDiv.querySelector('.item-article').value;
        const description = itemDiv.querySelector('.item-description').value;
        const quantity = parseFloat(itemDiv.querySelector('.item-quantity').value);
        const unitPrice = parseFloat(itemDiv.querySelector('.item-price').value);

        if (description && quantity && unitPrice) {
            items.push({
                article_id: articleId || null,
                description,
                quantity,
                unit_price: unitPrice
            });
        }
    });

    if (items.length === 0) {
        showToast('Bitte mindestens eine Position hinzufügen', 'error');
        return;
    }

    const data = {
        customer_id: parseInt(document.getElementById('invoiceCustomer').value),
        invoice_date: document.getElementById('invoiceDate').value,
        due_date: document.getElementById('invoiceDueDate').value,
        notes: document.getElementById('invoiceNotes').value,
        items
    };

    try {
        await api.post('/invoices', data);
        showToast('Rechnung erstellt', 'success');
        closeModal();
        loadInvoices();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function viewInvoice(id) {
    try {
        const invoice = await api.get(`/invoices/${id}`);

        const itemsHtml = invoice.items?.map(item => `
            <tr>
                <td>${item.description}</td>
                <td>${item.quantity}</td>
                <td>${formatCurrency(item.unit_price)}</td>
                <td>${formatCurrency(item.quantity * item.unit_price)}</td>
            </tr>
        `).join('') || '<tr><td colspan="4">Keine Positionen</td></tr>';

        const content = `
            <div style="margin-bottom: 20px;">
                <p><strong>Rechnungsnummer:</strong> ${invoice.invoice_number}</p>
                <p><strong>Kunde:</strong> ${invoice.customer?.name || '-'}</p>
                <p><strong>Datum:</strong> ${formatDate(invoice.invoice_date)}</p>
                <p><strong>Fällig:</strong> ${formatDate(invoice.due_date)}</p>
                <p><strong>Status:</strong> <span class="status-badge status-${invoice.status}">${getStatusText(invoice.status)}</span></p>
            </div>
            <table class="data-table" style="width: 100%;">
                <thead>
                    <tr>
                        <th>Beschreibung</th>
                        <th>Menge</th>
                        <th>Preis</th>
                        <th>Gesamt</th>
                    </tr>
                </thead>
                <tbody>${itemsHtml}</tbody>
                <tfoot>
                    <tr>
                        <td colspan="3" style="text-align: right;"><strong>Gesamtbetrag:</strong></td>
                        <td><strong>${formatCurrency(invoice.total_amount)}</strong></td>
                    </tr>
                </tfoot>
            </table>
            ${invoice.notes ? `<p style="margin-top: 15px;"><strong>Notizen:</strong> ${invoice.notes}</p>` : ''}
            <div style="margin-top: 20px; text-align: right;">
                <button class="btn btn-primary" onclick="downloadInvoicePDF(${invoice.id})">PDF herunterladen</button>
                <button class="btn btn-success" onclick="sendInvoiceEmail(${invoice.id})">Per E-Mail senden</button>
            </div>
        `;

        showModal(`Rechnung ${invoice.invoice_number}`, content);
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function downloadInvoicePDF(id) {
    try {
        const response = await fetch(`${API_BASE_URL}/invoices/${id}/pdf`, {
            headers: {
                'Authorization': `Bearer ${AppState.token}`
            }
        });

        if (!response.ok) throw new Error('PDF konnte nicht erstellt werden');

        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `rechnung_${id}.pdf`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        a.remove();

        showToast('PDF heruntergeladen', 'success');
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function sendInvoiceEmail(id) {
    const invoice = AppState.invoices.find(i => i.id === id);
    const defaultEmail = invoice?.customer?.email || '';

    const email = prompt('E-Mail-Adresse des Empfängers:', defaultEmail);
    if (!email) return;

    try {
        await api.post('/email/send-invoice', {
            invoice_id: id,
            recipient_email: email
        });
        showToast('E-Mail gesendet', 'success');
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// ============================================
// Customers
// ============================================

async function loadCustomers() {
    const tableBody = document.getElementById('customersTableBody');
    if (tableBody) {
        tableBody.innerHTML = '<tr><td colspan="6" class="loading">Lade Kunden...</td></tr>';
    }

    try {
        AppState.customers = await api.get('/customers');
        if (tableBody) {
            renderCustomersTable();
        }
    } catch (error) {
        if (tableBody) {
            tableBody.innerHTML = `<tr><td colspan="6" class="loading">Fehler: ${error.message}</td></tr>`;
        }
    }
}

function renderCustomersTable() {
    const tableBody = document.getElementById('customersTableBody');

    if (AppState.customers.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="6" class="loading">Keine Kunden vorhanden</td></tr>';
        return;
    }

    tableBody.innerHTML = AppState.customers.map(customer => `
        <tr>
            <td>${customer.name}</td>
            <td>${customer.company || '-'}</td>
            <td>${customer.email || '-'}</td>
            <td>${customer.phone || '-'}</td>
            <td>${customer.city || '-'}</td>
            <td>
                <button class="btn btn-sm btn-secondary" onclick="editCustomer(${customer.id})">Bearbeiten</button>
                <button class="btn btn-sm btn-danger" onclick="deleteCustomer(${customer.id})">Löschen</button>
            </td>
        </tr>
    `).join('');
}

function createNewCustomer() {
    showCustomerModal();
}

function showCustomerModal(customer = null) {
    const isEdit = customer !== null;

    const content = `
        <form id="customerForm" data-customer-id="${customer?.id || ''}">
            <div class="form-group">
                <label for="customerName">Name *</label>
                <input type="text" id="customerName" value="${customer?.name || ''}" required>
            </div>
            <div class="form-group">
                <label for="customerCompany">Firma</label>
                <input type="text" id="customerCompany" value="${customer?.company || ''}">
            </div>
            <div class="form-group">
                <label for="customerEmail">E-Mail</label>
                <input type="email" id="customerEmail" value="${customer?.email || ''}">
            </div>
            <div class="form-group">
                <label for="customerPhone">Telefon</label>
                <input type="text" id="customerPhone" value="${customer?.phone || ''}">
            </div>
            <div class="form-group">
                <label for="customerStreet">Straße</label>
                <input type="text" id="customerStreet" value="${customer?.street || ''}">
            </div>
            <div style="display: flex; gap: 15px;">
                <div class="form-group" style="flex: 1;">
                    <label for="customerZip">PLZ</label>
                    <input type="text" id="customerZip" value="${customer?.zip_code || ''}">
                </div>
                <div class="form-group" style="flex: 2;">
                    <label for="customerCity">Ort</label>
                    <input type="text" id="customerCity" value="${customer?.city || ''}">
                </div>
            </div>
            <div style="margin-top: 20px; text-align: right;">
                <button type="button" class="btn btn-secondary" onclick="closeModal()">Abbrechen</button>
                <button type="submit" class="btn btn-primary">${isEdit ? 'Aktualisieren' : 'Erstellen'}</button>
            </div>
        </form>
    `;

    showModal(isEdit ? 'Kunde bearbeiten' : 'Neuer Kunde', content);
    document.getElementById('customerForm').addEventListener('submit', handleCustomerSubmit);
}

async function editCustomer(id) {
    const customer = AppState.customers.find(c => c.id === id);
    if (customer) {
        showCustomerModal(customer);
    }
}

async function handleCustomerSubmit(event) {
    event.preventDefault();

    const form = event.target;
    const customerId = form.dataset.customerId;

    const data = {
        name: document.getElementById('customerName').value,
        company: document.getElementById('customerCompany').value || null,
        email: document.getElementById('customerEmail').value || null,
        phone: document.getElementById('customerPhone').value || null,
        street: document.getElementById('customerStreet').value || null,
        zip_code: document.getElementById('customerZip').value || null,
        city: document.getElementById('customerCity').value || null
    };

    try {
        if (customerId) {
            await api.put(`/customers/${customerId}`, data);
            showToast('Kunde aktualisiert', 'success');
        } else {
            await api.post('/customers', data);
            showToast('Kunde erstellt', 'success');
        }

        closeModal();
        loadCustomers();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function deleteCustomer(id) {
    if (!confirm('Möchten Sie diesen Kunden wirklich löschen?')) return;

    try {
        await api.delete(`/customers/${id}`);
        showToast('Kunde gelöscht', 'success');
        loadCustomers();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// ============================================
// Articles
// ============================================

async function loadArticles() {
    const tableBody = document.getElementById('articlesTableBody');
    if (tableBody) {
        tableBody.innerHTML = '<tr><td colspan="6" class="loading">Lade Artikel...</td></tr>';
    }

    try {
        AppState.articles = await api.get('/articles');
        if (tableBody) {
            renderArticlesTable();
        }
    } catch (error) {
        if (tableBody) {
            tableBody.innerHTML = `<tr><td colspan="6" class="loading">Fehler: ${error.message}</td></tr>`;
        }
    }
}

function renderArticlesTable() {
    const tableBody = document.getElementById('articlesTableBody');

    if (AppState.articles.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="6" class="loading">Keine Artikel vorhanden</td></tr>';
        return;
    }

    tableBody.innerHTML = AppState.articles.map(article => `
        <tr>
            <td>${article.article_number || '-'}</td>
            <td>${article.name}</td>
            <td>${article.category || '-'}</td>
            <td>${formatCurrency(article.price)}</td>
            <td>${article.unit || 'Stück'}</td>
            <td>
                <button class="btn btn-sm btn-secondary" onclick="editArticle(${article.id})">Bearbeiten</button>
                <button class="btn btn-sm btn-danger" onclick="deleteArticle(${article.id})">Löschen</button>
            </td>
        </tr>
    `).join('');
}

function createNewArticle() {
    showArticleModal();
}

function showArticleModal(article = null) {
    const isEdit = article !== null;

    const content = `
        <form id="articleForm" data-article-id="${article?.id || ''}">
            <div class="form-group">
                <label for="articleNumber">Artikel-Nr.</label>
                <input type="text" id="articleNumber" value="${article?.article_number || ''}">
            </div>
            <div class="form-group">
                <label for="articleName">Name *</label>
                <input type="text" id="articleName" value="${article?.name || ''}" required>
            </div>
            <div class="form-group">
                <label for="articleDescription">Beschreibung</label>
                <textarea id="articleDescription" rows="2">${article?.description || ''}</textarea>
            </div>
            <div class="form-group">
                <label for="articleCategory">Kategorie</label>
                <input type="text" id="articleCategory" value="${article?.category || ''}">
            </div>
            <div style="display: flex; gap: 15px;">
                <div class="form-group" style="flex: 1;">
                    <label for="articlePrice">Preis (€) *</label>
                    <input type="number" id="articlePrice" step="0.01" value="${article?.price || ''}" required>
                </div>
                <div class="form-group" style="flex: 1;">
                    <label for="articleUnit">Einheit</label>
                    <select id="articleUnit">
                        <option value="Stück" ${article?.unit === 'Stück' ? 'selected' : ''}>Stück</option>
                        <option value="kg" ${article?.unit === 'kg' ? 'selected' : ''}>kg</option>
                        <option value="g" ${article?.unit === 'g' ? 'selected' : ''}>g</option>
                        <option value="Glas" ${article?.unit === 'Glas' ? 'selected' : ''}>Glas</option>
                        <option value="Liter" ${article?.unit === 'Liter' ? 'selected' : ''}>Liter</option>
                    </select>
                </div>
            </div>
            <div style="margin-top: 20px; text-align: right;">
                <button type="button" class="btn btn-secondary" onclick="closeModal()">Abbrechen</button>
                <button type="submit" class="btn btn-primary">${isEdit ? 'Aktualisieren' : 'Erstellen'}</button>
            </div>
        </form>
    `;

    showModal(isEdit ? 'Artikel bearbeiten' : 'Neuer Artikel', content);
    document.getElementById('articleForm').addEventListener('submit', handleArticleSubmit);
}

async function editArticle(id) {
    const article = AppState.articles.find(a => a.id === id);
    if (article) {
        showArticleModal(article);
    }
}

async function handleArticleSubmit(event) {
    event.preventDefault();

    const form = event.target;
    const articleId = form.dataset.articleId;

    const data = {
        article_number: document.getElementById('articleNumber').value || null,
        name: document.getElementById('articleName').value,
        description: document.getElementById('articleDescription').value || null,
        category: document.getElementById('articleCategory').value || null,
        price: parseFloat(document.getElementById('articlePrice').value),
        unit: document.getElementById('articleUnit').value || 'Stück'
    };

    try {
        if (articleId) {
            await api.put(`/articles/${articleId}`, data);
            showToast('Artikel aktualisiert', 'success');
        } else {
            await api.post('/articles', data);
            showToast('Artikel erstellt', 'success');
        }

        closeModal();
        loadArticles();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function deleteArticle(id) {
    if (!confirm('Möchten Sie diesen Artikel wirklich löschen?')) return;

    try {
        await api.delete(`/articles/${id}`);
        showToast('Artikel gelöscht', 'success');
        loadArticles();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// ============================================
// Settings & Backup
// ============================================

async function createBackup() {
    try {
        showToast('Backup wird erstellt...', 'info');
        const result = await api.post('/backup/create', {});
        showToast(`Backup erstellt: ${result.filename}`, 'success');
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function listBackups() {
    try {
        const backups = await api.get('/backup/list');

        if (backups.length === 0) {
            showModal('Backups', '<p>Keine Backups vorhanden</p>');
            return;
        }

        const content = `
            <table class="data-table" style="width: 100%;">
                <thead>
                    <tr>
                        <th>Dateiname</th>
                        <th>Datum</th>
                        <th>Größe</th>
                        <th>Aktionen</th>
                    </tr>
                </thead>
                <tbody>
                    ${backups.map(backup => `
                        <tr>
                            <td>${backup.filename}</td>
                            <td>${formatDate(backup.created_at)}</td>
                            <td>${formatFileSize(backup.size)}</td>
                            <td>
                                <button class="btn btn-sm btn-secondary" onclick="downloadBackup('${backup.filename}')">Download</button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;

        showModal('Backups', content);
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function downloadBackup(filename) {
    try {
        const response = await fetch(`${API_BASE_URL}/backup/download/${filename}`, {
            headers: {
                'Authorization': `Bearer ${AppState.token}`
            }
        });

        if (!response.ok) throw new Error('Download fehlgeschlagen');

        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        a.remove();

        showToast('Backup heruntergeladen', 'success');
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function checkEmailConfig() {
    try {
        const status = await api.get('/email/config-status');

        const content = `
            <div style="padding: 10px;">
                <p><strong>E-Mail-Server Status:</strong></p>
                <p style="color: ${status.configured ? 'var(--success-color)' : 'var(--danger-color)'};">
                    ${status.configured ? '✓ Konfiguriert' : '✗ Nicht konfiguriert'}
                </p>
                ${status.smtp_host ? `<p><strong>SMTP Server:</strong> ${status.smtp_host}</p>` : ''}
                ${!status.configured ? `
                    <p style="margin-top: 15px; color: var(--text-muted);">
                        Bitte konfigurieren Sie die E-Mail-Einstellungen in der Backend .env Datei.
                    </p>
                ` : ''}
            </div>
        `;

        showModal('E-Mail Status', content);
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function showProfileSettings() {
    const user = AppState.user;

    const content = `
        <form id="profileForm">
            <div class="form-group">
                <label for="profileUsername">Benutzername</label>
                <input type="text" id="profileUsername" value="${user?.username || ''}" required>
            </div>
            <div class="form-group">
                <label for="profileEmail">E-Mail</label>
                <input type="email" id="profileEmail" value="${user?.email || ''}" required>
            </div>
            <div class="form-group">
                <label for="profileFullName">Vollständiger Name</label>
                <input type="text" id="profileFullName" value="${user?.full_name || ''}">
            </div>
            <hr style="margin: 20px 0;">
            <p style="color: var(--text-muted); margin-bottom: 10px;">Passwort ändern (optional):</p>
            <div class="form-group">
                <label for="profileOldPassword">Altes Passwort</label>
                <input type="password" id="profileOldPassword">
            </div>
            <div class="form-group">
                <label for="profileNewPassword">Neues Passwort</label>
                <input type="password" id="profileNewPassword">
            </div>
            <div style="margin-top: 20px; text-align: right;">
                <button type="button" class="btn btn-secondary" onclick="closeModal()">Abbrechen</button>
                <button type="submit" class="btn btn-primary">Speichern</button>
            </div>
        </form>
    `;

    showModal('Profil bearbeiten', content);
    document.getElementById('profileForm').addEventListener('submit', handleProfileSubmit);
}

async function handleProfileSubmit(event) {
    event.preventDefault();

    const oldPassword = document.getElementById('profileOldPassword').value;
    const newPassword = document.getElementById('profileNewPassword').value;

    // Update profile
    try {
        const data = {
            username: document.getElementById('profileUsername').value,
            email: document.getElementById('profileEmail').value,
            full_name: document.getElementById('profileFullName').value,
            password: null
        };

        await api.put('/auth/me', data);

        // Change password if provided
        if (oldPassword && newPassword) {
            await api.post('/auth/change-password', null, {
                params: { old_password: oldPassword, new_password: newPassword }
            });
        }

        // Refresh user data
        AppState.user = await api.get('/auth/me');
        document.getElementById('userName').textContent = AppState.user.full_name || AppState.user.username;

        showToast('Profil aktualisiert', 'success');
        closeModal();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// ============================================
// Modal
// ============================================

function showModal(title, content) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML = content;
    document.getElementById('modalOverlay').style.display = 'flex';
}

function closeModal() {
    document.getElementById('modalOverlay').style.display = 'none';
}

// ============================================
// UI Helpers
// ============================================

function updateConnectionStatus(online) {
    const dot = document.querySelector('.status-dot');
    const text = document.querySelector('.status-text');

    if (online) {
        dot.classList.add('online');
        dot.classList.remove('offline');
        text.textContent = 'Verbunden';
    } else {
        dot.classList.remove('online');
        dot.classList.add('offline');
        text.textContent = 'Offline';
    }
}

function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
        toast.remove();
    }, 3000);
}

// ============================================
// Formatters
// ============================================

function formatCurrency(amount) {
    return new Intl.NumberFormat('de-DE', {
        style: 'currency',
        currency: 'EUR'
    }).format(amount);
}

function formatDate(dateString) {
    if (!dateString) return '-';
    return new Intl.DateTimeFormat('de-DE').format(new Date(dateString));
}

function formatFileSize(bytes) {
    if (!bytes) return '-';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function getStatusText(status) {
    const statusMap = {
        'draft': 'Entwurf',
        'sent': 'Versendet',
        'paid': 'Bezahlt',
        'overdue': 'Überfällig',
        'cancelled': 'Storniert'
    };
    return statusMap[status] || status;
}

// ============================================
// Event Listeners
// ============================================

document.addEventListener('DOMContentLoaded', async () => {
    // Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => {
            if (AppState.token) {
                showPage(item.dataset.page);
            }
        });
    });

    // Login form
    document.getElementById('loginForm').addEventListener('submit', handleLogin);

    // Register form
    document.getElementById('registerForm').addEventListener('submit', handleRegister);

    // Show register form
    document.getElementById('btnShowRegister').addEventListener('click', showRegisterForm);

    // Show login form
    document.getElementById('btnShowLogin').addEventListener('click', showLoginForm);

    // Logout button
    document.getElementById('btnLogout').addEventListener('click', logout);

    // Close modal on overlay click
    document.getElementById('modalOverlay').addEventListener('click', (e) => {
        if (e.target.id === 'modalOverlay') {
            closeModal();
        }
    });

    // Check for saved token
    const savedToken = localStorage.getItem('token');
    if (savedToken) {
        AppState.token = savedToken;
        try {
            AppState.user = await api.get('/auth/me');
            updateConnectionStatus(true);

            // Preload data
            await Promise.all([
                loadCustomers(),
                loadArticles()
            ]);

            showApp();
        } catch {
            localStorage.removeItem('token');
            showLogin();
        }
    } else {
        showLogin();
    }

    // Check server connection
    try {
        const response = await fetch(`${API_BASE_URL.replace('/api', '')}/health`);
        if (response.ok) {
            updateConnectionStatus(true);
        }
    } catch {
        updateConnectionStatus(false);
    }
});

// Global functions for onclick handlers
window.showPage = showPage;
window.createNewInvoice = createNewInvoice;
window.viewInvoice = viewInvoice;
window.downloadInvoicePDF = downloadInvoicePDF;
window.sendInvoiceEmail = sendInvoiceEmail;
window.createNewCustomer = createNewCustomer;
window.editCustomer = editCustomer;
window.deleteCustomer = deleteCustomer;
window.createNewArticle = createNewArticle;
window.editArticle = editArticle;
window.deleteArticle = deleteArticle;
window.addInvoiceItem = addInvoiceItem;
window.removeInvoiceItem = removeInvoiceItem;
window.updateItemFromArticle = updateItemFromArticle;
window.calculateItemTotal = calculateItemTotal;
window.closeModal = closeModal;
window.createBackup = createBackup;
window.listBackups = listBackups;
window.downloadBackup = downloadBackup;
window.checkEmailConfig = checkEmailConfig;
window.showProfileSettings = showProfileSettings;
