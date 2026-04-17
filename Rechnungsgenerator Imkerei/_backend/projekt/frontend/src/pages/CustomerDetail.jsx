import { useParams } from 'react-router-dom';

function CustomerDetail() {
  const { id } = useParams();

  return (
    <div className="card">
      <h2 className="text-2xl font-bold mb-6">Kunde #{id}</h2>
      <p className="text-gray-600">
        Hier werden die Kundendetails und Rechnungshistorie angezeigt.
      </p>
      {/* TODO: Implement customer detail view */}
    </div>
  );
}

export default CustomerDetail;
