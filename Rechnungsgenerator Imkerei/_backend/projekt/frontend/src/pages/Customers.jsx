import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { customersAPI } from '../services/api';

function Customers() {
  const { data: customers, isLoading } = useQuery({
    queryKey: ['customers'],
    queryFn: () => customersAPI.getAll().then((res) => res.data),
  });

  if (isLoading) return <div>Lädt...</div>;

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-3xl font-bold text-gray-900">Kunden</h2>
        <button className="btn btn-primary">
          Neuer Kunde
        </button>
      </div>

      <div className="card">
        {customers && customers.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {customers.map((customer) => (
              <Link
                key={customer.id}
                to={`/customers/${customer.id}`}
                className="p-4 border border-gray-200 rounded-lg hover:border-primary-500 hover:shadow-md transition"
              >
                <h3 className="font-bold text-lg">{customer.name}</h3>
                {customer.company && (
                  <p className="text-sm text-gray-600">{customer.company}</p>
                )}
                {customer.email && (
                  <p className="text-sm text-gray-500 mt-2">{customer.email}</p>
                )}
              </Link>
            ))}
          </div>
        ) : (
          <p className="text-center py-8 text-gray-500">
            Keine Kunden vorhanden. Erstellen Sie Ihren ersten Kunden!
          </p>
        )}
      </div>
    </div>
  );
}

export default Customers;
