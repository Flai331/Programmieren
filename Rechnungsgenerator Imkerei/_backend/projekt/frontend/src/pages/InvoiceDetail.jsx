import { useParams } from 'react-router-dom';

function InvoiceDetail() {
  const { id } = useParams();

  return (
    <div className="card">
      <h2 className="text-2xl font-bold mb-6">Rechnung #{id}</h2>
      <p className="text-gray-600">
        Hier werden die Rechnungsdetails angezeigt.
      </p>
      {/* TODO: Implement invoice detail view */}
    </div>
  );
}

export default InvoiceDetail;
