import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
});

// Customers
export const customersAPI = {
  getAll: (params) => api.get('/customers/', { params }),
  getOne: (id) => api.get(`/customers/${id}`),
  create: (data) => api.post('/customers/', data),
  update: (id, data) => api.put(`/customers/${id}`, data),
  delete: (id) => api.delete(`/customers/${id}`),
};

// Invoices
export const invoicesAPI = {
  getAll: (params) => api.get('/invoices/', { params }),
  getOne: (id) => api.get(`/invoices/${id}`),
  create: (data) => api.post('/invoices/', data),
  update: (id, data) => api.put(`/invoices/${id}`, data),
  delete: (id) => api.delete(`/invoices/${id}`),
  markSent: (id) => api.post(`/invoices/${id}/mark-sent`),
  markPaid: (id) => api.post(`/invoices/${id}/mark-paid`),
  downloadPDF: (id) => api.get(`/invoices/${id}/pdf`, { responseType: 'blob' }),
};

// Articles
export const articlesAPI = {
  getAll: (params) => api.get('/articles/', { params }),
  getOne: (id) => api.get(`/articles/${id}`),
  create: (data) => api.post('/articles/', data),
  update: (id, data) => api.put(`/articles/${id}`, data),
  delete: (id) => api.delete(`/articles/${id}`),
};

// Templates
export const templatesAPI = {
  getAll: (params) => api.get('/templates/', { params }),
  getOne: (id) => api.get(`/templates/${id}`),
  create: (data) => api.post('/templates/', data),
  update: (id, data) => api.put(`/templates/${id}`, data),
  delete: (id) => api.delete(`/templates/${id}`),
  uploadPDF: (id, file) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post(`/templates/${id}/upload-pdf`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
  uploadLogo: (id, file) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post(`/templates/${id}/upload-logo`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
};

// Statistics
export const statisticsAPI = {
  getInvoiceStats: (params) => api.get('/statistics/invoices', { params }),
  getCustomerStats: (id) => api.get(`/statistics/customers/${id}`),
  getTopCustomers: (limit) => api.get('/statistics/top-customers', { params: { limit } }),
};

export default api;
