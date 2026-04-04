export const db = async (path) => {
  const r = await fetch(`/api${path}`)
  if (!r.ok) throw new Error(`API ${r.status}: ${r.statusText}`)
  return r.json()
}
export const dbPost = async (path, body) => {
  const r = await fetch(`/api${path}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  })
  return r.json()
}

const ERGAST = 'https://api.jolpi.ca/ergast/f1'
export const F1_YEAR = 2025

const erg = async (path) => {
  const r = await fetch(`${ERGAST}${path}`)
  if (!r.ok) throw new Error(`Jolpica ${r.status}`)
  return r.json()
}

export const f1Standings = async () => {
  const d = await erg(`/${F1_YEAR}/driverStandings.json`)
  const list = d?.MRData?.StandingsTable?.StandingsLists?.[0]?.DriverStandings || []
  return list.map(s => ({
    position: parseInt(s.position),
    driver_name: `${s.Driver.givenName} ${s.Driver.familyName}`,
    driver_number: s.Driver.permanentNumber,
    abbreviation: s.Driver.code,
    nationality: s.Driver.nationality,
    team_name: s.Constructors?.[0]?.name || '—',
    total_points: parseFloat(s.points),
    wins: parseInt(s.wins),
    driver_id: s.Driver.driverId,
  }))
}

export const f1ConStandings = async () => {
  const d = await erg(`/${F1_YEAR}/constructorStandings.json`)
  const list = d?.MRData?.StandingsTable?.StandingsLists?.[0]?.ConstructorStandings || []
  return list.map(s => ({
    position: parseInt(s.position),
    team_name: s.Constructor.name,
    nationality: s.Constructor.nationality,
    total_points: parseFloat(s.points),
    wins: parseInt(s.wins),
  }))
}

export const f1Races = async () => {
  const d = await erg(`/${F1_YEAR}.json`)
  return (d?.MRData?.RaceTable?.Races || []).map(r => ({
    round: parseInt(r.round), race_id: r.round,
    race_name: r.raceName,
    circuit_name: r.Circuit.circuitName,
    circuit_country: r.Circuit.Location.country,
    city: r.Circuit.Location.locality,
    race_date: r.date,
    status: new Date(r.date) < new Date() ? 'Completed' : 'Scheduled',
  }))
}

export const f1Results = async (round) => {
  const d = await erg(`/${F1_YEAR}/${round}/results.json`)
  return (d?.MRData?.RaceTable?.Races?.[0]?.Results || []).map(r => ({
    finishing_position: parseInt(r.position),
    driver_name: `${r.Driver.givenName} ${r.Driver.familyName}`,
    driver_number: r.Driver.permanentNumber,
    nationality: r.Driver.nationality,
    team_name: r.Constructor.name,
    grid_position: parseInt(r.grid),
    points_earned: parseFloat(r.points),
    laps_completed: parseInt(r.laps),
    result_status: r.status,
    race_time: r.Time?.time || r.status,
    fastest_lap: r.FastestLap?.rank === '1',
  }))
}
