import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { statisticsAPI, invoicesAPI } from '../services/api';

function Dashboard() {
  const { data: stats } = useQuery({
    queryKey: ['invoiceStats'],
    queryFn: () => statisticsAPI.getInvoiceStats().then((res) => res.data),
  });

  const { data: recentInvoices } = useQuery({
    queryKey: ['recentInvoices'],
    queryFn: () => invoicesAPI.getAll({ limit: 5 }).then((res) => res.data),
  });

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-3xl font-bold text-gray-900">Dashboard</h2>
        <Link to="/invoices/new" className="btn btn-primary">
          Neue Rechnung
        </Link>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="card">
          <h3 className="text-sm font-medium text-gray-500">Gesamtumsatz</h3>
          <p className="text-3xl font-bold text-gray-900 mt-2">
            {stats?.total_revenue?.toFixed(2) || '0.00'} €
          </p>
        </div>

        <div className="card">
          <h3 className="text-sm font-medium text-gray-500">Offene Posten</h3>
          <p className="text-3xl font-bold text-gray-900 mt-2">
            {stats?.total_outstanding?.toFixed(2) || '0.00'} €
          </p>
        </div>

        <div className="card">
          <h3 className="text-sm font-medium text-gray-500">Bezahlte Rechnungen</h3>
          <p className="text-3xl font-bold text-gray-900 mt-2">
            {stats?.paid_invoices || 0}
          </p>
        </div>

        <div className="card">
          <h3 className="text-sm font-medium text-gray-500">Überfällige Rechnungen</h3>
          <p className="text-3xl font-bold text-red-600 mt-2">
            {stats?.overdue_invoices || 0}
          </p>
        </div>
      </div>

      {/* Recent Invoices */}
      <div className="card">
        <h3 className="text-xl font-bold mb-4">Aktuelle Rechnungen</h3>
        {recentInvoices && recentInvoices.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Rechnungsnr.
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Datum
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Betrag
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {recentInvoices.map((invoice) => (
                  <tr key={invoice.id}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <Link
                        to={`/invoices/${invoice.id}`}
                        className="text-primary-600 hover:text-primary-900"
                      >
                        {invoice.invoice_number}
                      </Link>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {new Date(invoice.invoice_date).toLocaleDateString('de-DE')}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span
                        className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                          invoice.status === 'paid'
                            ? 'bg-green-100 text-green-800'
                            : invoice.status === 'overdue'
                            ? 'bg-red-100 text-red-800'
                            : 'bg-yellow-100 text-yellow-800'
                        }`}
                      >
                        {invoice.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {invoice.total.toFixed(2)} €
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-gray-500">Keine Rechnungen vorhanden</p>
        )}
      </div>
    </div>
  );
}

export default Dashboard;
