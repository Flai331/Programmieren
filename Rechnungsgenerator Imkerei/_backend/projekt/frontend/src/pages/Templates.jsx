function Templates() {
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-3xl font-bold text-gray-900">Vorlagen</h2>
        <button className="btn btn-primary">
          Neue Vorlage
        </button>
      </div>

      <div className="card">
        <p className="text-gray-600">
          Hier können Sie PDF-Vorlagen hochladen und Rechnungsköpfe verwalten.
        </p>
        {/* TODO: Implement template upload and management */}
      </div>
    </div>
  );
}

export default Templates;
