function Articles() {
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-3xl font-bold text-gray-900">Artikel</h2>
        <button className="btn btn-primary">
          Neuer Artikel
        </button>
      </div>

      <div className="card">
        <p className="text-gray-600">
          Hier wird der Artikel-Katalog angezeigt.
        </p>
        {/* TODO: Implement articles list and management */}
      </div>
    </div>
  );
}

export default Articles;
