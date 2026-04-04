import React, { useState, useEffect, useRef, useCallback } from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
         ResponsiveContainer, Legend, BarChart, Bar, AreaChart, Area } from 'recharts'
import { db, dbPost, f1Standings, f1ConStandings, f1Races, f1Results, F1_YEAR } from './api.js'

// ── Sport config ──────────────────────────────────────────────
const SPORTS = {
  f1:     { key:'f1',     label:'F1',     name:'Formula 1',          year:F1_YEAR, color:'#ff1801', glow:'rgba(255,24,1,.28)',    dim:'#7a0900', live:true,  seasonId:1, champId:1, vehicle:'f1car'     },
  motogp: { key:'motogp', label:'MotoGP', name:'MotoGP',             year:2023,    color:'#3b82f6', glow:'rgba(59,130,246,.28)',  dim:'#1e3a8a', live:false, seasonId:3, champId:2, vehicle:'moto'      },
  nascar: { key:'nascar', label:'NASCAR', name:'NASCAR Cup',         year:2023,    color:'#f59e0b', glow:'rgba(245,158,11,.28)',  dim:'#78350f', live:false, seasonId:4, champId:3, vehicle:'stockcar'  },
  wrc:    { key:'wrc',    label:'WRC',    name:'World Rally Champ.', year:2023,    color:'#10b981', glow:'rgba(16,185,129,.28)',  dim:'#064e3b', live:false, seasonId:5, champId:4, vehicle:'rallycar'  },
}

const TABS = [
  { id:'standings', label:'Standings'  },
  { id:'races',     label:'Races'      },
  { id:'drivers',   label:'Drivers'    },
  { id:'teams',     label:'Teams'      },
  { id:'circuits',  label:'Circuits'   },
  { id:'analytics', label:'Analytics'  },
  { id:'admin',     label:'Admin'      },
]

// ── useFetch ──────────────────────────────────────────────────
function useFetch(fn, deps=[]) {
  const [d,setD]=useState(null),[l,setL]=useState(true),[e,setE]=useState(null)
  useEffect(()=>{
    if(!fn){setL(false);return}
    let x=false; setL(true); setE(null)
    Promise.resolve(fn())
      .then(r=>{if(!x){setD(r);setL(false)}})
      .catch(err=>{if(!x){setE(err.message);setL(false)}})
    return()=>{x=true}
  },deps)
  return{data:d,loading:l,error:e}
}

// ── useCounter (animated number) ─────────────────────────────
function useCounter(target, duration=1200) {
  const [val,setVal]=useState(0)
  useEffect(()=>{
    if(!target) return
    let start=0, step=target/60, frame=duration/60
    const t=setInterval(()=>{
      start+=step
      if(start>=target){setVal(target);clearInterval(t)}
      else setVal(Math.floor(start))
    },frame)
    return()=>clearInterval(t)
  },[target])
  return val
}

// ── SVG Vehicles ──────────────────────────────────────────────
const F1Car = ({color='#ff1801',size=90}) => (
  <svg width={size} height={size*0.4} viewBox="0 0 200 80" fill="none">
    <ellipse cx="100" cy="52" rx="72" ry="14" fill={color} opacity=".12"/>
    {/* body */}
    <path d="M30 45 Q40 30 70 28 L130 28 Q160 30 170 45 L165 52 L35 52 Z" fill={color}/>
    {/* cockpit */}
    <path d="M75 28 Q90 16 110 16 Q125 16 130 28 Z" fill={color} opacity=".7"/>
    {/* nose */}
    <path d="M165 46 L188 49 L165 52 Z" fill={color} opacity=".8"/>
    <path d="M35 46 L12 49 L35 52 Z" fill={color} opacity=".8"/>
    {/* front wing */}
    <rect x="10" y="48" width="26" height="4" rx="2" fill={color} opacity=".6"/>
    {/* rear wing */}
    <rect x="164" y="42" width="22" height="4" rx="2" fill={color} opacity=".6"/>
    <rect x="168" y="38" width="14" height="2" rx="1" fill={color} opacity=".4"/>
    {/* wheels */}
    <circle cx="55" cy="54" r="12" fill="#1a1a2e" stroke={color} strokeWidth="3"/>
    <circle cx="55" cy="54" r="5" fill={color} opacity=".4"/>
    <circle cx="145" cy="54" r="12" fill="#1a1a2e" stroke={color} strokeWidth="3"/>
    <circle cx="145" cy="54" r="5" fill={color} opacity=".4"/>
    <circle cx="42" cy="54" r="9" fill="#1a1a2e" stroke={color} strokeWidth="2.5"/>
    <circle cx="158" cy="54" r="9" fill="#1a1a2e" stroke={color} strokeWidth="2.5"/>
    {/* halo */}
    <path d="M88 18 Q100 14 112 18" stroke={color} strokeWidth="2.5" fill="none" opacity=".7"/>
  </svg>
)

const Moto = ({color='#3b82f6',size=90}) => (
  <svg width={size} height={size*0.55} viewBox="0 0 200 100" fill="none">
    <ellipse cx="100" cy="75" rx="60" ry="10" fill={color} opacity=".1"/>
    {/* rear wheel */}
    <circle cx="60" cy="72" r="22" fill="#1a1a2e" stroke={color} strokeWidth="4"/>
    <circle cx="60" cy="72" r="8"  fill={color} opacity=".3"/>
    {/* front wheel */}
    <circle cx="155" cy="72" r="20" fill="#1a1a2e" stroke={color} strokeWidth="4"/>
    <circle cx="155" cy="72" r="7"  fill={color} opacity=".3"/>
    {/* frame */}
    <path d="M60 52 L90 38 L130 36 L155 52" stroke={color} strokeWidth="4" fill="none" strokeLinecap="round"/>
    {/* body fairing */}
    <path d="M80 52 Q100 30 130 36 L140 52 Q120 58 80 52Z" fill={color} opacity=".75"/>
    {/* windscreen */}
    <path d="M125 36 Q138 30 148 40 L140 44 Q132 38 125 36Z" fill={color} opacity=".4"/>
    {/* rider */}
    <ellipse cx="105" cy="36" rx="12" ry="10" fill={color} opacity=".6"/>
    <circle cx="108" cy="26" r="8" fill={color} opacity=".5"/>
    {/* fork */}
    <line x1="140" y1="48" x2="155" y2="52" stroke={color} strokeWidth="3" strokeLinecap="round"/>
    {/* exhaust */}
    <path d="M70 54 Q55 56 50 60" stroke={color} strokeWidth="3" fill="none" strokeLinecap="round" opacity=".5"/>
  </svg>
)

const StockCar = ({color='#f59e0b',size=100}) => (
  <svg width={size} height={size*0.42} viewBox="0 0 240 90" fill="none">
    <ellipse cx="120" cy="68" rx="88" ry="12" fill={color} opacity=".1"/>
    {/* body */}
    <path d="M28 54 Q35 38 65 34 L175 34 Q205 38 212 54 L210 64 L30 64 Z" fill={color}/>
    {/* roof */}
    <path d="M72 34 Q90 22 120 20 Q150 22 168 34 Z" fill={color} opacity=".7"/>
    {/* windshield */}
    <path d="M78 34 Q96 26 120 24 Q144 26 162 34 Q148 38 92 38 Z" fill={color} opacity=".25"/>
    {/* number plate area */}
    <rect x="95" y="36" width="50" height="16" rx="2" fill="rgba(0,0,0,.4)"/>
    <text x="120" y="48" textAnchor="middle" fill={color} fontSize="11" fontWeight="bold" fontFamily="monospace">48</text>
    {/* wheels */}
    <circle cx="70"  cy="66" r="16" fill="#111" stroke={color} strokeWidth="4"/>
    <circle cx="70"  cy="66" r="6"  fill={color} opacity=".4"/>
    <circle cx="170" cy="66" r="16" fill="#111" stroke={color} strokeWidth="4"/>
    <circle cx="170" cy="66" r="6"  fill={color} opacity=".4"/>
    {/* front bumper */}
    <rect x="210" y="52" width="18" height="10" rx="3" fill={color} opacity=".5"/>
    {/* rear bumper */}
    <rect x="12" y="52" width="18" height="10" rx="3" fill={color} opacity=".5"/>
    {/* door line */}
    <line x1="120" y1="36" x2="120" y2="62" stroke="rgba(0,0,0,.3)" strokeWidth="1.5"/>
    {/* sponsor stripe */}
    <rect x="30" y="50" width="80" height="8" fill="rgba(255,255,255,.08)"/>
    <rect x="130" y="50" width="80" height="8" fill="rgba(255,255,255,.08)"/>
  </svg>
)

const RallyCar = ({color='#10b981',size=100}) => (
  <svg width={size} height={size*0.44} viewBox="0 0 240 94" fill="none">
    <ellipse cx="120" cy="72" rx="80" ry="12" fill={color} opacity=".1"/>
    {/* body */}
    <path d="M30 56 Q42 38 72 34 L168 34 Q198 38 210 56 L208 66 L32 66 Z" fill={color}/>
    {/* roof */}
    <path d="M76 34 Q100 20 120 18 Q145 20 164 34 Z" fill={color} opacity=".7"/>
    {/* windshield */}
    <path d="M82 34 Q100 24 120 22 Q142 24 158 34 Q142 40 98 40 Z" fill={color} opacity=".3"/>
    {/* roof lights */}
    <rect x="88" y="18" width="64" height="8" rx="3" fill="white" opacity=".9"/>
    <circle cx="96"  cy="22" r="3" fill={color}/>
    <circle cx="108" cy="22" r="3" fill={color}/>
    <circle cx="120" cy="22" r="3" fill={color}/>
    <circle cx="132" cy="22" r="3" fill={color}/>
    <circle cx="144" cy="22" r="3" fill={color}/>
    {/* rally wheels */}
    <circle cx="72"  cy="68" r="18" fill="#111" stroke={color} strokeWidth="4.5"/>
    <circle cx="72"  cy="68" r="7"  fill={color} opacity=".4"/>
    <circle cx="168" cy="68" r="18" fill="#111" stroke={color} strokeWidth="4.5"/>
    <circle cx="168" cy="68" r="7"  fill={color} opacity=".4"/>
    {/* front grille */}
    <rect x="205" y="50" width="20" height="14" rx="3" fill={color} opacity=".5"/>
    <line x1="205" y1="55" x2="225" y2="55" stroke="rgba(0,0,0,.4)" strokeWidth="1"/>
    <line x1="205" y1="60" x2="225" y2="60" stroke="rgba(0,0,0,.4)" strokeWidth="1"/>
    {/* mud flaps / rally look */}
    <rect x="32" y="60" width="12" height="10" rx="1" fill={color} opacity=".4"/>
    <rect x="196" y="60" width="12" height="10" rx="1" fill={color} opacity=".4"/>
    {/* headlights */}
    <ellipse cx="210" cy="48" rx="6" ry="5" fill="white" opacity=".7"/>
    <ellipse cx="218" cy="48" rx="4" ry="4" fill="white" opacity=".5"/>
  </svg>
)

const VEHICLES = { f1car: F1Car, moto: Moto, stockcar: StockCar, rallycar: RallyCar }

// ── Animated Racing Banner ────────────────────────────────────
function RacingBanner({cfg}) {
  const VComp = VEHICLES[cfg.vehicle]
  return (
    <div style={{position:'relative',height:72,overflow:'hidden',borderBottom:`1px solid ${cfg.color}20`,background:`linear-gradient(90deg, ${cfg.color}05 0%, transparent 50%, ${cfg.color}05 100%)`}}>
      {/* Scanline effect */}
      <div style={{position:'absolute',top:0,left:0,right:0,bottom:0,backgroundImage:`repeating-linear-gradient(0deg, transparent, transparent 3px, ${cfg.color}04 3px, ${cfg.color}04 4px)`,pointerEvents:'none'}}/>
      {/* Racing stripes */}
      <div style={{position:'absolute',top:'50%',left:0,right:0,height:1,background:`linear-gradient(90deg, transparent, ${cfg.color}30, transparent)`,transform:'translateY(-50%)'}}/>
      {/* Driving vehicle */}
      <div style={{position:'absolute',top:'50%',transform:'translateY(-55%)',animation:`drive ${cfg.key==='nascar'?'6s':'8s'} linear infinite`,animationDelay:'-2s'}}>
        <div style={{filter:`drop-shadow(0 0 8px ${cfg.color})`}}>
          <VComp color={cfg.color} size={cfg.key==='f1'?80:90}/>
        </div>
      </div>
      {/* Sport label */}
      <div style={{position:'absolute',right:20,top:'50%',transform:'translateY(-50%)',fontFamily:'var(--display)',fontSize:28,color:cfg.color,opacity:.15,letterSpacing:'0.06em'}}>
        {cfg.name.toUpperCase()}
      </div>
      {/* Speed lines */}
      {[...Array(5)].map((_,i)=>(
        <div key={i} style={{position:'absolute',top:`${20+i*12}%`,left:0,height:1,background:`linear-gradient(90deg, transparent, ${cfg.color}20, transparent)`,width:`${30+i*10}%`,animation:`drive ${3+i*.5}s linear infinite`,animationDelay:`${-i*1.2}s`}}/>
      ))}
    </div>
  )
}

// ── Animated stat number ──────────────────────────────────────
function AnimatedStat({val,label,color}) {
  const counted = useCounter(parseInt(val)||0)
  return (
    <div style={{textAlign:'center',animation:'countUp .6s ease both'}}>
      <div style={{fontFamily:'var(--display)',fontSize:42,color,lineHeight:1,letterSpacing:'0.02em',filter:`drop-shadow(0 0 10px ${color}60)`}}>
        {counted}
      </div>
      <div style={{fontSize:10,color:'var(--muted)',marginTop:5,letterSpacing:'0.1em',textTransform:'uppercase',fontFamily:'var(--mono)'}}>{label}</div>
    </div>
  )
}

// ── Atoms ─────────────────────────────────────────────────────
const Spin=({c='var(--c)'})=>(
  <div style={{display:'flex',alignItems:'center',justifyContent:'center',padding:60}}>
    <div style={{width:28,height:28,border:'2px solid var(--border)',borderTopColor:c,borderRadius:'50%',animation:'spin .7s linear infinite'}}/>
  </div>
)
const ErrBox=({msg})=>(
  <div style={{margin:16,padding:'12px 16px',background:'#1a0008',border:'1px solid #ff180130',color:'#ff6050',borderRadius:8,fontSize:12,fontFamily:'var(--mono)'}}>⚠ {msg}</div>
)
const Live=()=>(
  <span style={{display:'inline-flex',alignItems:'center',gap:5,background:'rgba(255,24,1,.1)',border:'1px solid rgba(255,24,1,.3)',color:'#ff6050',padding:'2px 9px',borderRadius:20,fontSize:9,fontWeight:600,letterSpacing:'0.1em',fontFamily:'var(--mono)'}}>
    <span style={{width:5,height:5,background:'#ff1801',borderRadius:'50%',animation:'pulse 1s ease infinite'}}/> LIVE
  </span>
)
const Pos=({n})=>{
  const c=n===1?'#f59e0b':n===2?'#9ca3af':n===3?'#c07840':'var(--muted)'
  return <span style={{fontFamily:'var(--mono)',fontWeight:700,fontSize:15,color:c,minWidth:30,display:'inline-block'}}>{n||'—'}</span>
}
const Mono=({v,c='var(--text)',bold=false,size=12})=>(
  <span style={{fontFamily:'var(--mono)',fontSize:size,color:c,fontWeight:bold?700:400}}>{v}</span>
)
const Tag=({text,color})=>(
  <span style={{display:'inline-block',padding:'2px 9px',borderRadius:4,fontFamily:'var(--mono)',fontSize:9,fontWeight:600,letterSpacing:'0.08em',background:`${color}18`,color,border:`1px solid ${color}35`}}>
    {text}
  </span>
)
const Card=({children,style={}})=>(
  <div style={{background:'var(--card)',border:'1px solid var(--border)',borderRadius:'var(--radius)',...style}}>
    {children}
  </div>
)
const SecHead=({children,right})=>(
  <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'12px 18px',borderBottom:'1px solid var(--border)'}}>
    <span style={{fontFamily:'var(--mono)',fontSize:9,fontWeight:500,letterSpacing:'0.12em',textTransform:'uppercase',color:'var(--muted)'}}>{children}</span>
    {right}
  </div>
)
const Back=({onClick})=>(
  <button onClick={onClick} style={{background:'none',border:'1px solid var(--border)',cursor:'pointer',padding:'6px 14px',borderRadius:6,fontSize:12,color:'var(--muted)',marginBottom:18,fontFamily:'var(--sans)',fontWeight:500,transition:'all .15s'}}
    onMouseEnter={e=>{e.target.style.borderColor='var(--c)';e.target.style.color='var(--c)'}}
    onMouseLeave={e=>{e.target.style.borderColor='var(--border)';e.target.style.color='var(--muted)'}}>
    ← Back
  </button>
)

// ── Data Table ────────────────────────────────────────────────
function DT({cols,rows=[],empty='No data available.'}) {
  if(!rows.length) return <div style={{padding:48,textAlign:'center',color:'var(--muted)',fontSize:13}}>{empty}</div>
  return (
    <div style={{overflowX:'auto'}}>
      <table>
        <thead><tr>{cols.map(c=><th key={c.k} style={c.hs}>{c.l}</th>)}</tr></thead>
        <tbody>{rows.map((r,i)=>(
          <tr key={i} onClick={r._click} style={r._click?{cursor:'pointer'}:{}}>
            {cols.map(c=><td key={c.k} style={c.ts}>{c.r?c.r(r):r[c.k]}</td>)}
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

// ── SubTabs ───────────────────────────────────────────────────
const SubTabs=({tabs,active,set,cfg})=>(
  <div style={{display:'flex',gap:4,marginBottom:16,flexWrap:'wrap'}}>
    {tabs.map(t=>(
      <button key={t.id} onClick={()=>set(t.id)} style={{
        padding:'6px 16px',borderRadius:6,cursor:'pointer',
        fontFamily:'var(--sans)',fontSize:13,fontWeight:600,
        border:active===t.id?`1px solid ${cfg.color}`:'1px solid var(--border)',
        background:active===t.id?`${cfg.color}12`:'transparent',
        color:active===t.id?cfg.color:'var(--muted)',
        transition:'all .15s',letterSpacing:'0.02em',
      }}>{t.label}</button>
    ))}
  </div>
)

// ── Stats row ─────────────────────────────────────────────────
const StatsRow=({items,cfg})=>(
  <div style={{display:'grid',gridTemplateColumns:`repeat(${items.length},1fr)`,gap:12,marginBottom:22}}>
    {items.map(x=>(
      <div key={x.l} style={{background:'var(--bg2)',border:`1px solid ${cfg.color}20`,borderRadius:'var(--radius)',padding:'14px 16px',textAlign:'center',transition:'border-color .2s'}}
        onMouseEnter={e=>e.currentTarget.style.borderColor=cfg.color}
        onMouseLeave={e=>e.currentTarget.style.borderColor=`${cfg.color}20`}>
        <AnimatedStat val={x.v} label={x.l} color={cfg.color}/>
      </div>
    ))}
  </div>
)

// ─────────────────────────────────────────────────────────────
// STANDINGS
// ─────────────────────────────────────────────────────────────
function Standings({sport,cfg}) {
  const [sub,setSub]=useState('drivers')

  // Live F1
  const {data:ld,loading:ll,error:le}=useFetch(cfg.live?f1Standings:null,[sport,sub])
  const {data:lc,loading:lcl,error:lce}=useFetch(cfg.live&&sub==='constructors'?f1ConStandings:null,[sport,sub])

  // DB drivers
  const {data:dd,loading:dl,error:de}=useFetch(!cfg.live?()=>db(`/standings/drivers?seasonId=${cfg.seasonId}`):null,[sport,sub])

  // DB constructors — first try standings view, fallback to teams with race points
  const {data:dc,loading:dcl,error:dce}=useFetch(
    !cfg.live&&sub==='constructors'
      ? ()=>db(`/standings/constructors?seasonId=${cfg.seasonId}`)
          .then(d=>d&&d.length?d:db(`/teams`).then(teams=>
            db(`/races?seasonId=${cfg.seasonId}`).then(races=>{
              const teamIds=new Set(races?.map(r=>r.team_id)||[])
              // Get teams that participated in this championship
              return db(`/results?seasonId=${cfg.seasonId}`).then(results=>{
                if(!results) return teams
                const tpts={}
                results.forEach(r=>{
                  if(!tpts[r.team_id]) tpts[r.team_id]={team_name:r.team_name,team_id:r.team_id,total_points:0,wins:0,nationality:'—'}
                  tpts[r.team_id].total_points+=parseFloat(r.points_earned||0)
                  if(r.finishing_position===1) tpts[r.team_id].wins++
                })
                return Object.values(tpts)
                  .sort((a,b)=>b.total_points-a.total_points)
                  .map((t,i)=>({...t,position:i+1}))
              })
            })
          ))
      : null,
    [sport,sub]
  )

  const drivers=cfg.live?ld:dd, cons=cfg.live?lc:dc
  const loading=sub==='drivers'?(cfg.live?ll:dl):(cfg.live?lcl:dcl)
  const error=sub==='drivers'?(cfg.live?le:de):(cfg.live?lce:dce)

  return (
    <div className="fade-up">
      <div style={{display:'flex',gap:8,alignItems:'center',marginBottom:18,flexWrap:'wrap'}}>
        <SubTabs tabs={[{id:'drivers',label:'Drivers'},{id:'constructors',label:'Constructors'}]} active={sub} set={setSub} cfg={cfg}/>
        {cfg.live&&<Live/>}
      </div>
      <Card>
        {loading?<Spin c={cfg.color}/>:error?<ErrBox msg={error}/>:sub==='drivers'?(
          <DT cols={[
            {k:'p',l:'',r:r=><Pos n={r.position}/>,hs:{width:44,paddingLeft:18}},
            {k:'n',l:'Driver',r:r=><div><div style={{fontWeight:600,fontSize:14,letterSpacing:'0.01em'}}>{r.driver_name}</div><div style={{fontSize:10,color:'var(--muted)',fontFamily:'var(--mono)',marginTop:1}}>{r.abbreviation||''}{r.driver_number?` · #${r.driver_number}`:''}</div></div>},
            {k:'nat',l:'Nationality',r:r=><span style={{color:'var(--muted)',fontSize:12}}>{r.nationality}</span>},
            {k:'t',l:'Team',r:r=><span style={{fontSize:13,fontWeight:500}}>{r.team_name}</span>},
            {k:'pts',l:'Points',r:r=><Mono v={r.total_points} c={cfg.color} bold size={14}/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
            {k:'w',l:'W',r:r=><Mono v={r.wins||0} c={r.wins>0?cfg.color:'var(--muted)'}/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
            {k:'pod',l:'Pod',r:r=><Mono v={r.podiums||'—'} c='var(--muted)'/>,hs:{textAlign:'right',paddingRight:18},ts:{textAlign:'right',paddingRight:18}},
          ]} rows={drivers||[]} empty={`No ${cfg.name} driver standings yet.`}/>
        ):(
          <DT cols={[
            {k:'p',l:'',r:r=><Pos n={r.position}/>,hs:{width:44,paddingLeft:18}},
            {k:'t',l:'Constructor',r:r=><span style={{fontWeight:600,fontSize:14}}>{r.team_name}</span>},
            {k:'nat',l:'Country',r:r=><span style={{color:'var(--muted)',fontSize:12}}>{r.nationality||r.team_country||'—'}</span>},
            {k:'pts',l:'Points',r:r=><Mono v={parseFloat(r.total_points||0).toFixed(0)} c={cfg.color} bold size={14}/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
            {k:'w',l:'Wins',r:r=><Mono v={r.wins||0} c='var(--muted)'/>,hs:{textAlign:'right',paddingRight:18},ts:{textAlign:'right',paddingRight:18}},
          ]} rows={cons||[]} empty={`No ${cfg.name} constructor data yet.`}/>
        )}
      </Card>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// RACES
// ─────────────────────────────────────────────────────────────
function Races({sport,cfg}) {
  const [sel,setSel]=useState(null)
  const {data:lr,loading:lrl}=useFetch(cfg.live?f1Races:null,[sport])
  const {data:dr,loading:drl}=useFetch(!cfg.live?()=>db(`/races?seasonId=${cfg.seasonId}`):null,[sport])
  const races=cfg.live?lr:dr, rload=cfg.live?lrl:drl
  const {data:lres,loading:lresl}=useFetch(cfg.live&&sel?()=>f1Results(sel):null,[sel])
  const {data:dres,loading:dresl}=useFetch(!cfg.live&&sel?()=>db(`/results?raceId=${sel}`):null,[sel])
  const results=cfg.live?lres:dres, resLoad=cfg.live?lresl:dresl

  const statusTag=(r)=>{
    const done=r.status==='Completed'||(r.race_date&&new Date(r.race_date)<new Date())
    return <Tag text={done?'DONE':'UPCOMING'} color={done?'#10b981':cfg.color}/>
  }

  if(sel) {
    const race=races?.find(r=>(r.race_id||r.round)==sel)
    return (
      <div className="fade-in">
        <Back onClick={()=>setSel(null)}/>
        <div style={{marginBottom:20}}>
          <div style={{fontFamily:'var(--display)',fontSize:34,letterSpacing:'0.04em',color:'var(--text)',lineHeight:1}}>{race?.race_name}</div>
          <div style={{fontSize:12,color:'var(--muted)',marginTop:6,fontFamily:'var(--mono)'}}>{race?.circuit_name} · {race?.race_date?.slice(0,10)} · Round {race?.round_number||race?.round}</div>
        </div>
        <Card>
          <SecHead>Results — {cfg.name} {cfg.year}{cfg.live&&<span style={{marginLeft:8}}><Live/></span>}</SecHead>
          {resLoad?<Spin c={cfg.color}/>:(
            <DT cols={[
              {k:'p',l:'',r:r=><Pos n={r.finishing_position}/>,hs:{width:44,paddingLeft:18}},
              {k:'d',l:'Driver',r:r=><div><div style={{fontWeight:600}}>{r.driver_name}</div><div style={{fontSize:10,color:'var(--muted)'}}>{r.driver_nationality||r.nationality}</div></div>},
              {k:'t',l:'Team',r:r=><span style={{fontSize:12,color:'var(--muted)'}}>{r.team_name}</span>},
              {k:'g',l:'Grid',r:r=><Mono v={r.grid_position} c='var(--muted)'/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'pts',l:'Pts',r:r=><Mono v={r.points_earned} c={cfg.color} bold/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
              {k:'laps',l:'Laps',r:r=><Mono v={r.laps_completed} c='var(--muted)'/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
              {k:'time',l:'Time',r:r=><Mono v={r.race_time||r.result_status||'—'} c='var(--muted)'/>,hs:{paddingRight:18},ts:{paddingRight:18}},
            ]} rows={results||[]} empty="No results for this race yet."/>
          )}
        </Card>
      </div>
    )
  }

  return (
    <div className="fade-up">
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:16}}>
        {cfg.live&&<Live/>}
        <span style={{fontSize:12,color:'var(--muted)'}}>{cfg.name} {cfg.year} · {races?.length||0} rounds · Click a race to view results</span>
      </div>
      <Card>
        {rload?<Spin c={cfg.color}/>:(
          <DT cols={[
            {k:'rd',l:'Rd',r:r=><Mono v={r.round_number||r.round} c='var(--muted)'/>,hs:{width:44,paddingLeft:18}},
            {k:'name',l:'Race',r:r=><span style={{fontWeight:600,letterSpacing:'0.01em'}}>{r.race_name}</span>},
            {k:'cir',l:'Circuit',r:r=><span style={{fontSize:12,color:'var(--muted)'}}>{r.circuit_name}</span>},
            {k:'cou',l:'Country',r:r=><span style={{fontSize:12,color:'var(--muted)'}}>{r.circuit_country||r.country}</span>},
            {k:'date',l:'Date',r:r=><Mono v={r.race_date?.slice(0,10)} c='var(--muted)'/>,ts:{fontSize:11}},
            {k:'laps',l:'Laps',r:r=><Mono v={r.total_laps||'—'} c='var(--muted)'/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
            {k:'st',l:'Status',r:statusTag,hs:{paddingRight:18},ts:{paddingRight:18}},
          ]} rows={(races||[]).map(r=>({...r,_click:()=>setSel(r.race_id||r.round)}))} empty="No races found."/>
        )}
      </Card>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// DRIVERS
// ─────────────────────────────────────────────────────────────
function Drivers({sport,cfg}) {
  const [sel,setSel]=useState(null)
  const {data:ld}=useFetch(cfg.live?f1Standings:null,[sport])
  const {data:dd,loading:dl}=useFetch(!cfg.live?()=>db(`/standings/drivers?seasonId=${cfg.seasonId}`):null,[sport])
  const {data:det,loading:detl}=useFetch(!cfg.live&&sel?()=>db(`/drivers/${sel}`):null,[sel])
  const drivers=cfg.live?ld:dd, loading=cfg.live?false:dl

  if(!cfg.live&&sel) return (
    <div className="fade-in">
      <Back onClick={()=>setSel(null)}/>
      {detl?<Spin c={cfg.color}/>:det&&(
        <>
          <div style={{display:'flex',gap:20,alignItems:'center',marginBottom:24}}>
            <div style={{width:68,height:68,borderRadius:'50%',background:`${cfg.color}12`,border:`2px solid ${cfg.color}40`,display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'var(--mono)',fontWeight:700,fontSize:17,color:cfg.color,flexShrink:0,animation:'borderPulse 2s ease infinite'}}>
              {det.abbreviation}
            </div>
            <div>
              <div style={{fontFamily:'var(--display)',fontSize:36,letterSpacing:'0.04em',lineHeight:1}}>{det.first_name} {det.last_name}</div>
              <div style={{fontSize:12,color:'var(--muted)',marginTop:4,fontFamily:'var(--mono)'}}>#{det.driver_number} · {det.nationality} · {det.date_of_birth?.slice(0,10)}</div>
            </div>
          </div>
          <StatsRow cfg={cfg} items={[
            {v:parseFloat(det.stats?.total_points||0).toFixed(0),l:'Points'},
            {v:det.stats?.races||0,l:'Races'},
            {v:det.stats?.wins||0,l:'Wins'},
            {v:det.stats?.podiums||0,l:'Podiums'},
            {v:det.stats?.best_finish||'—',l:'Best Finish'},
          ]}/>
          <Card>
            <SecHead>Race History</SecHead>
            <DT cols={[
              {k:'rn',l:'Race',r:r=><span style={{fontWeight:600}}>{r.race_name}</span>},
              {k:'yr',l:'Year',r:r=><Mono v={r.season_year} c='var(--muted)'/>,ts:{fontSize:12}},
              {k:'pos',l:'Pos',r:r=><Pos n={r.finishing_position}/>},
              {k:'pts',l:'Pts',r:r=><Mono v={r.points_earned} c={cfg.color} bold/>,hs:{textAlign:'right',paddingRight:18},ts:{textAlign:'right',paddingRight:18}},
              {k:'st',l:'Status',r:r=><span style={{fontSize:12,color:'var(--muted)'}}>{r.result_status}</span>},
            ]} rows={det.results||[]} empty="No results yet."/>
          </Card>
        </>
      )}
    </div>
  )

  return (
    <div className="fade-up">
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:16}}>
        {cfg.live&&<Live/>}
        {!cfg.live&&<span style={{fontSize:12,color:'var(--muted)'}}>Click a driver for full profile · {drivers?.length||0} drivers</span>}
      </div>
      <Card>
        {loading?<Spin c={cfg.color}/>:(
          <DT cols={[
            {k:'p',l:'',r:r=><Pos n={r.position}/>,hs:{width:44,paddingLeft:18}},
            {k:'n',l:'Driver',r:r=><div><div style={{fontWeight:600,fontSize:14}}>{r.driver_name}</div><div style={{fontSize:10,color:'var(--muted)',fontFamily:'var(--mono)'}}>{r.abbreviation||''}</div></div>},
            {k:'nat',l:'Nationality',r:r=><span style={{color:'var(--muted)',fontSize:12}}>{r.nationality}</span>},
            {k:'t',l:'Team',r:r=><span style={{fontSize:13,fontWeight:500}}>{r.team_name}</span>},
            {k:'pts',l:'Pts',r:r=><Mono v={r.total_points} c={cfg.color} bold size={14}/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
            {k:'w',l:'W',r:r=><Mono v={r.wins||0} c='var(--muted)'/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
            {k:'pod',l:'Pod',r:r=><Mono v={r.podiums||'—'} c='var(--muted)'/>,hs:{textAlign:'right',paddingRight:18},ts:{textAlign:'right',paddingRight:18}},
          ]} rows={(drivers||[]).map(r=>({...r,_click:!cfg.live?()=>setSel(r.driver_id):undefined}))} empty="No drivers found."/>
        )}
      </Card>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// TEAMS
// ─────────────────────────────────────────────────────────────
function Teams({sport,cfg}) {
  // For all sports: first try constructor standings, fallback to aggregated race data
  const {data,loading,error}=useFetch(
    ()=>db(`/standings/constructors?seasonId=${cfg.seasonId}`)
      .then(d=>{
        if(d&&d.length) return d
        // Fallback: aggregate points from results for this season
        return db(`/results?seasonId=${cfg.seasonId}`).then(results=>{
          if(!results||!results.length) return []
          const tmap={}
          results.forEach(r=>{
            if(!r.team_name) return
            if(!tmap[r.team_name]) tmap[r.team_name]={team_name:r.team_name,total_points:0,wins:0,nationality:'—',position:0}
            tmap[r.team_name].total_points+=parseFloat(r.points_earned||0)
            if(r.finishing_position===1) tmap[r.team_name].wins++
          })
          return Object.values(tmap)
            .sort((a,b)=>b.total_points-a.total_points)
            .map((t,i)=>({...t,position:i+1}))
        })
      }),
    [sport]
  )

  // For F1 live override
  const {data:lc,loading:ll}=useFetch(cfg.live?f1ConStandings:null,[sport])
  const finalData=cfg.live?(lc||data):data
  const finalLoading=cfg.live?ll:loading

  return (
    <div className="fade-up">
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:16}}>
        {cfg.live&&<Live/>}
        <span style={{fontSize:12,color:'var(--muted)'}}>{cfg.name} {cfg.year} — Constructor Championship</span>
      </div>
      <Card>
        {finalLoading?<Spin c={cfg.color}/>:error?<ErrBox msg={error}/>:(
          <DT cols={[
            {k:'p',l:'',r:r=><Pos n={r.position}/>,hs:{width:44,paddingLeft:18}},
            {k:'t',l:'Constructor',r:r=><span style={{fontWeight:600,fontSize:14}}>{r.team_name}</span>},
            {k:'nat',l:'Country',r:r=><span style={{color:'var(--muted)',fontSize:12}}>{r.nationality||r.team_country||'—'}</span>},
            {k:'pts',l:'Points',r:r=><Mono v={parseFloat(r.total_points||0).toFixed(0)} c={cfg.color} bold size={14}/>,hs:{textAlign:'right'},ts:{textAlign:'right'}},
            {k:'w',l:'Wins',r:r=><Mono v={r.wins||0} c='var(--muted)'/>,hs:{textAlign:'right',paddingRight:18},ts:{textAlign:'right',paddingRight:18}},
          ]} rows={finalData||[]} empty={`No ${cfg.name} constructor data yet.`}/>
        )}
      </Card>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// CIRCUITS
// ─────────────────────────────────────────────────────────────
function Circuits({sport,cfg}) {
  const {data:lr}=useFetch(cfg.live?f1Races:null,[sport])
  const {data:ci,loading:cil}=useFetch(!cfg.live?()=>db('/circuits'):null,[sport])
  const {data:sr}=useFetch(!cfg.live?()=>db(`/races?seasonId=${cfg.seasonId}`):null,[sport])
  const VComp=VEHICLES[cfg.vehicle]

  let data,loading
  if(cfg.live){
    const seen=new Set()
    data=(lr||[]).filter(r=>{if(seen.has(r.circuit_name))return false;seen.add(r.circuit_name);return true})
      .map(r=>({circuit_name:r.circuit_name,city:r.city,country_name:r.circuit_country,circuit_type:'Permanent',times_hosted:1}))
    loading=!lr
  } else {
    const ids=new Set((sr||[]).map(r=>r.circuit_id))
    data=ids.size?(ci||[]).filter(c=>ids.has(c.circuit_id)):ci||[]
    loading=cil
  }

  return (
    <div className="fade-up">
      <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:16}}>
        {cfg.live&&<Live/>}
        <span style={{fontSize:12,color:'var(--muted)'}}>{cfg.name} {cfg.year} · {data?.length||0} venues</span>
      </div>
      {loading?<Spin c={cfg.color}/>:(
        <div style={{display:'grid',gridTemplateColumns:'repeat(auto-fill,minmax(250px,1fr))',gap:12}}>
          {(data||[]).map((c,i)=>(
            <div key={i} style={{background:'var(--card)',border:`1px solid var(--border)`,borderRadius:'var(--radius)',padding:16,transition:'all .2s',cursor:'default'}}
              onMouseEnter={e=>{e.currentTarget.style.borderColor=cfg.color;e.currentTarget.style.boxShadow=`0 4px 20px ${cfg.color}20`}}
              onMouseLeave={e=>{e.currentTarget.style.borderColor='var(--border)';e.currentTarget.style.boxShadow='none'}}>
              <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:10}}>
                <div>
                  <div style={{fontWeight:700,fontSize:13,lineHeight:1.3}}>{c.circuit_name}</div>
                  <div style={{fontSize:11,color:'var(--muted)',marginTop:3}}>{c.city}{c.city&&c.country_name?', ':''}{c.country_name}</div>
                </div>
                <Tag text={c.circuit_type||'Perm'} color={cfg.color}/>
              </div>
              <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:6}}>
                {c.track_length_km!=null&&<div style={{background:'var(--bg2)',borderRadius:5,padding:'6px 10px'}}>
                  <div style={{fontSize:9,color:'var(--muted)',letterSpacing:'0.08em',textTransform:'uppercase'}}>Length</div>
                  <div style={{fontFamily:'var(--mono)',fontWeight:700,fontSize:13,marginTop:2,color:cfg.color}}>{c.track_length_km} km</div>
                </div>}
                {c.capacity&&<div style={{background:'var(--bg2)',borderRadius:5,padding:'6px 10px'}}>
                  <div style={{fontSize:9,color:'var(--muted)',letterSpacing:'0.08em',textTransform:'uppercase'}}>Capacity</div>
                  <div style={{fontFamily:'var(--mono)',fontWeight:700,fontSize:12,marginTop:2}}>{parseInt(c.capacity).toLocaleString()}</div>
                </div>}
                {c.times_hosted!=null&&<div style={{background:'var(--bg2)',borderRadius:5,padding:'6px 10px'}}>
                  <div style={{fontSize:9,color:'var(--muted)',letterSpacing:'0.08em',textTransform:'uppercase'}}>Hosted</div>
                  <div style={{fontFamily:'var(--mono)',fontWeight:700,fontSize:12,marginTop:2}}>{c.times_hosted} races</div>
                </div>}
              </div>
              {/* Mini vehicle */}
              <div style={{marginTop:12,opacity:.4,transform:'scale(.7)',transformOrigin:'left center'}}>
                <VComp color={cfg.color} size={80}/>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// ANALYTICS
// ─────────────────────────────────────────────────────────────
const PALETTE=['#ff1801','#3b82f6','#10b981','#f59e0b','#a855f7','#f43f5e','#0ea5e9']

function Analytics({sport,cfg}) {
  const [sub,setSub]=useState('progression')
  const {data:cumul,loading:cl}=useFetch(()=>db(`/analytics/cumulative-points?seasonId=${cfg.seasonId}`),[sport])
  const {data:posit,loading:pl}=useFetch(()=>db(`/analytics/position-changes?seasonId=${cfg.seasonId}`),[sport])
  const {data:h2h,loading:hl}=useFetch(()=>db(`/analytics/teammate-h2h?seasonId=${cfg.seasonId}`),[sport])
  const {data:pit,loading:pitl}=useFetch(()=>db('/analytics/pit-stops'),[sport])

  const drvs=[...new Set((cumul||[]).map(d=>d.driver_name))].slice(0,7)
  const rnds=[...new Set((cumul||[]).map(d=>d.round_number))].sort((a,b)=>a-b)
  const chartData=rnds.map(rnd=>{
    const row={round:`R${rnd}`}
    drvs.forEach(drv=>{const pt=(cumul||[]).find(d=>d.driver_name===drv&&d.round_number===rnd);if(pt)row[drv]=parseFloat(pt.cumulative_points)})
    return row
  })

  const tipStyle={contentStyle:{background:'#0f0f1c',border:'1px solid var(--border)',borderRadius:8,fontSize:11},labelStyle:{color:'var(--muted)'}}

  return (
    <div className="fade-up">
      <SubTabs cfg={cfg} active={sub} set={setSub} tabs={[
        {id:'progression',label:'Points Progression'},
        {id:'positions',label:'Position Changes'},
        {id:'h2h',label:'Teammate H2H'},
        {id:'pitstops',label:'Pit Stop Impact'},
      ]}/>

      {sub==='progression'&&(
        <Card>
          <SecHead>SUM(pts) OVER (PARTITION BY driver ORDER BY round) — Window Function</SecHead>
          <div style={{padding:20}}>
            {cl?<Spin c={cfg.color}/>:chartData.length===0
              ?<div style={{textAlign:'center',padding:48,color:'var(--muted)',fontSize:13}}>No round-by-round data yet for {cfg.name}.</div>
              :<ResponsiveContainer width="100%" height={340}>
                <AreaChart data={chartData}>
                  <defs>
                    {drvs.map((d,i)=>(
                      <linearGradient key={d} id={`g${i}`} x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%"  stopColor={PALETTE[i%PALETTE.length]} stopOpacity={0.3}/>
                        <stop offset="95%" stopColor={PALETTE[i%PALETTE.length]} stopOpacity={0}/>
                      </linearGradient>
                    ))}
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--border)"/>
                  <XAxis dataKey="round" tick={{fontSize:10,fill:'var(--muted)'}}/>
                  <YAxis tick={{fontSize:10,fill:'var(--muted)'}}/>
                  <Tooltip {...tipStyle}/>
                  <Legend wrapperStyle={{fontSize:11,color:'var(--muted)'}}/>
                  {drvs.map((d,i)=>(
                    <Area key={d} type="monotone" dataKey={d} stroke={PALETTE[i%PALETTE.length]}
                      fill={`url(#g${i})`} strokeWidth={2} dot={{r:3}} connectNulls/>
                  ))}
                </AreaChart>
              </ResponsiveContainer>
            }
          </div>
        </Card>
      )}

      {sub==='positions'&&(
        <Card>
          <SecHead>LAG(position) OVER (PARTITION BY driver ORDER BY round) — Window Function</SecHead>
          {pl?<Spin c={cfg.color}/>:(
            <DT cols={[
              {k:'n',l:'Driver',r:r=><span style={{fontWeight:600}}>{r.driver_name}</span>},
              {k:'t',l:'Team',r:r=><span style={{fontSize:12,color:'var(--muted)'}}>{r.team_name}</span>},
              {k:'rd',l:'Round',r:r=><Mono v={`Rd ${r.after_round}`} c='var(--muted)'/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'pos',l:'Pos',r:r=><Mono v={r.position} bold/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'prev',l:'Prev',r:r=><Mono v={r.prev_position??'—'} c='var(--muted)'/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'chg',l:'Δ',r:r=>{const ch=r.position_change;if(ch==null)return<Mono v='—' c='var(--muted)'/>;if(ch<0)return<span style={{color:'#10b981',fontFamily:'var(--mono)',fontWeight:700}}>▲{Math.abs(ch)}</span>;if(ch>0)return<span style={{color:'#ff4040',fontFamily:'var(--mono)',fontWeight:700}}>▼{ch}</span>;return<Mono v='–' c='var(--muted)'/>;},hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'pts',l:'Pts',r:r=><Mono v={r.total_points} c={cfg.color} bold/>,hs:{textAlign:'right',paddingRight:18},ts:{textAlign:'right',paddingRight:18}},
            ]} rows={posit||[]} empty="No position snapshot data yet."/>
          )}
        </Card>
      )}

      {sub==='h2h'&&(
        <Card>
          <SecHead>Self Join on team_driver — Teammate Head-to-Head Comparison</SecHead>
          {hl?<Spin c={cfg.color}/>:(
            <DT cols={[
              {k:'t',l:'Team',r:r=><span style={{fontSize:12,color:'var(--muted)'}}>{r.team_name}</span>},
              {k:'d1',l:'Driver 1',r:r=><span style={{fontWeight:parseInt(r.d1_ahead)>parseInt(r.d2_ahead)?700:400,color:parseInt(r.d1_ahead)>parseInt(r.d2_ahead)?cfg.color:'var(--text)'}}>{r.driver1}</span>},
              {k:'a1',l:'Ahead',r:r=><Mono v={r.d1_ahead} c={cfg.color} bold/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'rc',l:'Races',r:r=><Mono v={r.races_together} c='var(--muted)'/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'a2',l:'Ahead',r:r=><Mono v={r.d2_ahead} c={cfg.color} bold/>,hs:{textAlign:'center'},ts:{textAlign:'center'}},
              {k:'d2',l:'Driver 2',r:r=><span style={{fontWeight:parseInt(r.d2_ahead)>parseInt(r.d1_ahead)?700:400,color:parseInt(r.d2_ahead)>parseInt(r.d1_ahead)?cfg.color:'var(--text)'}}>{r.driver2}</span>},
            ]} rows={h2h||[]} empty="Need results for both teammates in the same races."/>
          )}
        </Card>
      )}

      {sub==='pitstops'&&(
        <Card>
          <SecHead>CTE + AVG(finishing_position) grouped by pit stop count</SecHead>
          <div style={{padding:20}}>
            {pitl?<Spin c={cfg.color}/>:!pit?.length
              ?<div style={{textAlign:'center',padding:48,color:'var(--muted)',fontSize:13}}>Not enough pit stop data. F1 Bahrain has the most complete data.</div>
              :<ResponsiveContainer width="100%" height={280}>
                <BarChart data={pit}>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--border)"/>
                  <XAxis dataKey="stop_count" tick={{fontSize:10,fill:'var(--muted)'}} label={{value:'Pit Stops',position:'insideBottom',offset:-2,fill:'var(--muted)',fontSize:10}}/>
                  <YAxis reversed tick={{fontSize:10,fill:'var(--muted)'}} label={{value:'Avg Finish',angle:-90,position:'insideLeft',fill:'var(--muted)',fontSize:10}}/>
                  <Tooltip {...tipStyle}/>
                  <Bar dataKey="avg_finish_position" fill={cfg.color} name="Avg Finish Position" radius={[4,4,0,0]}/>
                </BarChart>
              </ResponsiveContainer>
            }
          </div>
        </Card>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// ADMIN
// ─────────────────────────────────────────────────────────────
function Admin() {
  const {data:races}=useFetch(()=>db('/races'))
  const {data:drivers}=useFetch(()=>db('/drivers'))
  const {data:teams}=useFetch(()=>db('/teams'))
  const {data:audit,loading:al}=useFetch(()=>db('/analytics/audit-log'))
  const [form,setForm]=useState({race_id:'',driver_id:'',team_id:'',finishing_position:'',grid_position:'',points_earned:'',laps_completed:'',status:'Finished',fastest_lap:false})
  const [msg,setMsg]=useState(null),[saving,setSaving]=useState(false)
  const [rankSeason,setRank]=useState(1),[rankMsg,setRankMsg]=useState(null)
  const set=(k,v)=>setForm(f=>({...f,[k]:v}))

  const submit=async()=>{
    setSaving(true);setMsg(null)
    try{
      const res=await dbPost('/results',{...form,finishing_position:parseInt(form.finishing_position),grid_position:parseInt(form.grid_position),points_earned:parseFloat(form.points_earned),laps_completed:parseInt(form.laps_completed)})
      setMsg(res.success?{ok:true,text:'✓ Result saved — trigger fired → standings updated + audit log entry written'}:{ok:false,text:res.error||'Error saving'})
      if(res.success)setForm({race_id:'',driver_id:'',team_id:'',finishing_position:'',grid_position:'',points_earned:'',laps_completed:'',status:'Finished',fastest_lap:false})
    }catch(e){setMsg({ok:false,text:e.message})}
    setSaving(false)
  }
  const callProc=async()=>{
    setRankMsg(null)
    try{const r=await dbPost('/admin/assign-rankings',{season_id:rankSeason});setRankMsg({ok:r.success,text:r.message||r.error})}
    catch(e){setRankMsg({ok:false,text:e.message})}
  }

  const fldStyle={padding:'8px 10px',background:'var(--bg3,#12121f)',border:'1px solid var(--border)',borderRadius:6,color:'var(--text)',fontSize:13,fontFamily:'var(--sans)',outline:'none',width:'100%',fontWeight:500}
  const Fld=({label,field,type='text',opts})=>(
    <div style={{display:'flex',flexDirection:'column',gap:4}}>
      <label style={{fontFamily:'var(--mono)',fontSize:9,fontWeight:500,letterSpacing:'0.12em',textTransform:'uppercase',color:'var(--muted)'}}>{label}</label>
      {opts
        ?<select value={form[field]} onChange={e=>set(field,e.target.value)} style={fldStyle}>
            <option value="">Select...</option>
            {opts.map(o=><option key={o.v} value={o.v}>{o.l}</option>)}
          </select>
        :<input type={type} value={form[field]} onChange={e=>set(field,e.target.value)} style={fldStyle}/>
      }
    </div>
  )

  return (
    <div className="fade-up" style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:20}}>
      <div style={{display:'flex',flexDirection:'column',gap:16}}>
        <Card style={{padding:20}}>
          <div style={{fontFamily:'var(--mono)',fontSize:9,letterSpacing:'0.12em',textTransform:'uppercase',color:'var(--muted)',marginBottom:16}}>Enter Race Result</div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:12}}>
            <Fld label="Race" field="race_id" opts={races?.map(r=>({v:r.race_id,l:`${r.race_name} (${r.season_year})`}))}/>
            <Fld label="Driver" field="driver_id" opts={drivers?.map(d=>({v:d.driver_id,l:`${d.first_name} ${d.last_name}`}))}/>
            <Fld label="Team" field="team_id" opts={teams?.map(t=>({v:t.team_id,l:t.team_name}))}/>
            <Fld label="Status" field="status" opts={[{v:'Finished',l:'Finished'},{v:'DNF',l:'DNF'},{v:'DNS',l:'DNS'},{v:'DSQ',l:'DSQ'}]}/>
            <Fld label="Finish Pos" field="finishing_position" type="number"/>
            <Fld label="Grid Pos"   field="grid_position"      type="number"/>
            <Fld label="Points"     field="points_earned"      type="number"/>
            <Fld label="Laps"       field="laps_completed"     type="number"/>
          </div>
          <div style={{display:'flex',alignItems:'center',gap:8,marginTop:12}}>
            <input type="checkbox" id="fl" checked={form.fastest_lap} onChange={e=>set('fastest_lap',e.target.checked)}/>
            <label htmlFor="fl" style={{fontSize:13,cursor:'pointer',fontWeight:500}}>Fastest Lap</label>
          </div>
          <button onClick={submit} disabled={saving} style={{width:'100%',marginTop:16,padding:'11px',background:'var(--c)',border:'none',borderRadius:6,color:'#fff',fontFamily:'var(--sans)',fontWeight:700,fontSize:13,cursor:'pointer',letterSpacing:'0.03em',opacity:saving?.6:1}}>
            {saving?'Saving...':'Save Result — Triggers Auto-Fire ↗'}
          </button>
          {msg&&<div style={{marginTop:10,padding:'10px 14px',borderRadius:6,fontSize:12,background:msg.ok?'#001a0e':'#1a0000',color:msg.ok?'#10b981':'#ff6050',border:`1px solid ${msg.ok?'#10b98130':'#ff180130'}`}}>{msg.text}</div>}
        </Card>
        <Card style={{padding:20}}>
          <div style={{fontFamily:'var(--mono)',fontSize:9,letterSpacing:'0.12em',textTransform:'uppercase',color:'var(--muted)',marginBottom:12}}>Call Stored Procedure</div>
          <div style={{fontSize:12,color:'var(--muted)',marginBottom:12}}>Calls <span style={{color:'var(--c)',fontFamily:'var(--mono)'}}>sp_assign_final_rankings()</span> — uses explicit cursor to rank all drivers in a season.</div>
          <div style={{display:'flex',gap:10,alignItems:'center'}}>
            <input type="number" value={rankSeason} min={1} onChange={e=>setRank(e.target.value)}
              style={{...fldStyle,width:90}} placeholder="Season"/>
            <button onClick={callProc} style={{padding:'8px 18px',background:'transparent',border:'1px solid var(--c)',borderRadius:6,color:'var(--c)',fontFamily:'var(--sans)',fontWeight:700,fontSize:12,cursor:'pointer',whiteSpace:'nowrap'}}>
              Run Procedure
            </button>
          </div>
          {rankMsg&&<div style={{marginTop:10,padding:'8px 12px',borderRadius:6,fontSize:12,background:rankMsg.ok?'#001a0e':'#1a0000',color:rankMsg.ok?'#10b981':'#ff6050',border:`1px solid ${rankMsg.ok?'#10b98130':'#ff180130'}`}}>{rankMsg.text}</div>}
        </Card>
      </div>
      <Card style={{display:'flex',flexDirection:'column',maxHeight:580,overflow:'hidden'}}>
        <SecHead>Audit Log — Trigger-generated entries</SecHead>
        <div style={{padding:'8px 16px',borderBottom:'1px solid var(--border)',fontSize:11,color:'var(--muted)'}}>
          Every INSERT / UPDATE / DELETE on <span style={{fontFamily:'var(--mono)'}}>race_result</span> logged automatically via triggers.
        </div>
        <div style={{overflowY:'auto',flex:1}}>
          {al?<Spin/>:(
            <DT cols={[
              {k:'id',l:'ID',r:r=><Mono v={r.log_id} c='var(--muted)'/>,hs:{paddingLeft:18},ts:{paddingLeft:18,fontSize:11}},
              {k:'act',l:'Action',r:r=>{const c=r.action==='INSERT'?'#10b981':r.action==='UPDATE'?'#3b82f6':'#ff4040';return<Tag text={r.action} color={c}/>}},
              {k:'tbl',l:'Table',r:r=><Mono v={r.table_name} c='var(--muted)'/>,ts:{fontSize:11}},
              {k:'rid',l:'Rec',r:r=><Mono v={`#${r.record_id}`} c='var(--muted)'/>,ts:{fontSize:11}},
              {k:'t',l:'Time',r:r=><Mono v={r.action_time?.slice(0,16)?.replace('T',' ')} c='var(--muted)'/>,ts:{fontSize:10,paddingRight:16},hs:{paddingRight:16}},
            ]} rows={audit||[]} empty="No audit entries yet. Save a result to see the trigger fire."/>
          )}
        </div>
      </Card>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// DASHBOARD
// ─────────────────────────────────────────────────────────────
function Dashboard({setPage,setSport}) {
  const {data:s}=useFetch(()=>db('/analytics/summary'))
  const {data:f1top}=useFetch(()=>db('/standings/drivers?seasonId=1'))
  const {data:wrctop}=useFetch(()=>db('/standings/drivers?seasonId=5'))

  const sportCards=[
    {key:'f1',color:'#ff1801',label:'F1',name:'Formula 1',desc:`Live ${F1_YEAR} Season`,vehicle:'f1car',sub:'FIA · 20 Rounds'},
    {key:'motogp',color:'#3b82f6',label:'MG',name:'MotoGP',desc:'2023 Season',vehicle:'moto',sub:'FIM · 20 Rounds'},
    {key:'nascar',color:'#f59e0b',label:'NA',name:'NASCAR Cup',desc:'2023 Season',vehicle:'stockcar',sub:'NASCAR · 36 Rounds'},
    {key:'wrc',color:'#10b981',label:'WR',name:'WRC Rally',desc:'2023 Season',vehicle:'rallycar',sub:'FIA · 13 Rallies'},
  ]

  return (
    <div style={{padding:'36px 40px',maxWidth:1160}}>
      {/* Hero */}
      <div style={{marginBottom:40,position:'relative'}}>
        <div style={{fontFamily:'var(--display)',fontSize:64,letterSpacing:'0.04em',lineHeight:.9,color:'var(--text)'}}>
          MOTORSPORT<br/>
          <span style={{color:'var(--c)',textShadow:'0 0 40px rgba(255,24,1,.5)'}}>DATABASE</span>
        </div>
        <div style={{fontSize:13,color:'var(--muted)',marginTop:16,fontFamily:'var(--mono)',letterSpacing:'0.04em'}}>
          MySQL 8.0 · Spring Boot 3 · React — 35 Tables · 4 Championships · Live F1 API
        </div>
        {/* Decorative line */}
        <div style={{position:'absolute',top:0,right:0,width:3,height:'100%',background:`linear-gradient(180deg, var(--c), transparent)`,borderRadius:2}}/>
      </div>

      {/* Stats */}
      {s&&(
        <div style={{display:'grid',gridTemplateColumns:'repeat(5,1fr)',gap:14,marginBottom:40}}>
          {[
            {v:s.total_championships,l:'Championships',c:'#ff1801'},
            {v:s.total_drivers,l:'Drivers',c:'#3b82f6'},
            {v:s.total_teams,l:'Teams',c:'#f59e0b'},
            {v:s.completed_races,l:'Races',c:'#10b981'},
            {v:s.total_results,l:'Results',c:'#a855f7'},
          ].map(x=>(
            <div key={x.l} style={{background:'var(--card)',border:`1px solid ${x.c}20`,borderRadius:'var(--radius)',padding:'18px 20px',transition:'all .2s'}}
              onMouseEnter={e=>{e.currentTarget.style.borderColor=x.c;e.currentTarget.style.boxShadow=`0 4px 20px ${x.c}20`}}
              onMouseLeave={e=>{e.currentTarget.style.borderColor=`${x.c}20`;e.currentTarget.style.boxShadow='none'}}>
              <AnimatedStat val={x.v} label={x.l} color={x.c}/>
            </div>
          ))}
        </div>
      )}

      {/* Sport cards */}
      <div style={{display:'grid',gridTemplateColumns:'repeat(4,1fr)',gap:14,marginBottom:36}}>
        {sportCards.map(sc=>{
          const VComp=VEHICLES[sc.vehicle]
          return(
          <div key={sc.key}
            onClick={()=>{setSport(sc.key);setPage('standings')}}
            style={{background:'var(--card)',border:`1px solid var(--border)`,borderRadius:'var(--radius)',padding:20,cursor:'pointer',transition:'all .2s',position:'relative',overflow:'hidden'}}
            onMouseEnter={e=>{e.currentTarget.style.borderColor=sc.color;e.currentTarget.style.boxShadow=`0 8px 32px ${sc.color}25`;e.currentTarget.style.transform='translateY(-2px)'}}
            onMouseLeave={e=>{e.currentTarget.style.borderColor='var(--border)';e.currentTarget.style.boxShadow='none';e.currentTarget.style.transform='none'}}>
            {/* BG glow */}
            <div style={{position:'absolute',top:0,right:0,width:80,height:80,background:sc.color,borderRadius:'50%',filter:'blur(40px)',opacity:.08,pointerEvents:'none'}}/>
            <div style={{fontFamily:'var(--display)',fontSize:11,letterSpacing:'0.16em',color:sc.color,marginBottom:6}}>{sc.sub}</div>
            <div style={{fontFamily:'var(--display)',fontSize:28,letterSpacing:'0.04em',lineHeight:1,marginBottom:4}}>{sc.name}</div>
            <div style={{fontSize:11,color:'var(--muted)',marginBottom:16}}>{sc.desc}</div>
            {/* Mini vehicle */}
            <div style={{opacity:.6,transform:'scale(.85)',transformOrigin:'left center'}}>
              <VComp color={sc.color} size={100}/>
            </div>
            <div style={{marginTop:10,fontSize:11,color:sc.color,fontWeight:600,fontFamily:'var(--sans)'}}>View standings →</div>
          </div>
        )})}
      </div>

      {/* Top 3 grids */}
      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:16}}>
        {[[f1top,'#ff1801','Formula 1','f1'],[wrctop,'#10b981','WRC Rally','wrc']].map(([list,color,name,sk])=>(
          <Card key={name}>
            <SecHead>{name} — Championship Top 3</SecHead>
            {(!list||!list.length)
              ?<div style={{padding:24,textAlign:'center',color:'var(--muted)',fontSize:13}}>No standings data yet.</div>
              :(list||[]).slice(0,3).map((d,i)=>(
              <div key={i} style={{display:'flex',alignItems:'center',gap:14,padding:'13px 18px',borderBottom:i<2?'1px solid var(--border)':'none'}}>
                <Pos n={i+1}/>
                <div style={{flex:1}}>
                  <div style={{fontWeight:700,fontSize:14}}>{d.driver_name}</div>
                  <div style={{fontSize:11,color:'var(--muted)',marginTop:1}}>{d.team_name}</div>
                </div>
                <div style={{fontFamily:'var(--mono)',fontWeight:700,fontSize:18,color}}>{d.total_points}<span style={{fontSize:10,color:'var(--muted)',fontWeight:400,marginLeft:3}}>pts</span></div>
              </div>
            ))}
            <div style={{padding:'12px 18px'}}>
              <button onClick={()=>{setSport(sk);setPage('standings')}} style={{background:'none',border:`1px solid ${color}40`,cursor:'pointer',padding:'6px 14px',borderRadius:6,fontSize:12,color,fontFamily:'var(--sans)',fontWeight:600,transition:'all .15s'}}
                onMouseEnter={e=>e.target.style.borderColor=color}
                onMouseLeave={e=>e.target.style.borderColor=`${color}40`}>
                Full standings →
              </button>
            </div>
          </Card>
        ))}
      </div>

      {/* DB Layer reference */}
      <div style={{marginTop:16}}>
        <Card>
          <SecHead>Database Objects Active</SecHead>
          <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:0}}>
            {[
              ['TRIGGER','trg_update_standings_insert','AFTER INSERT on race_result → auto-updates driver_standing'],
              ['TRIGGER','trg_audit_rr_insert/update/delete','Any change to race_result → writes JSON snapshot to audit_log'],
              ['PROCEDURE','sp_assign_final_rankings()','Called from Admin → cursor iterates drivers and assigns positions'],
              ['FUNCTION','fn_driver_avg_points()','Returns avg points per race for a driver in a season'],
              ['FUNCTION','fn_circuit_best_lap()','Returns all-time fastest lap at a given circuit'],
              ['VIEW','v_race_results_full','7-table join — all race info resolved to readable names'],
            ].map(([type,name,desc],i)=>(
              <div key={i} style={{padding:'12px 18px',borderBottom:i<3?'1px solid var(--border)':'none',borderRight:(i%3<2)?'1px solid var(--border)':'none'}}>
                <div style={{display:'flex',gap:8,alignItems:'center',marginBottom:5}}>
                  <Tag text={type} color={type==='TRIGGER'?'#ff1801':type==='PROCEDURE'?'#f59e0b':type==='FUNCTION'?'#3b82f6':'#10b981'}/>
                </div>
                <div style={{fontFamily:'var(--mono)',fontSize:11,fontWeight:600,color:'var(--text)',marginBottom:3}}>{name}</div>
                <div style={{fontSize:11,color:'var(--muted)'}}>{desc}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────
export default function App() {
  const [sport,setSport]=useState('f1')
  const [tab,setTab]=useState('dashboard')
  const cfg=SPORTS[sport]

  useEffect(()=>{
    document.documentElement.style.setProperty('--c',cfg.color)
    document.documentElement.style.setProperty('--c-glow',cfg.glow)
    document.documentElement.style.setProperty('--c-dim',cfg.dim)
  },[sport])

  const VComp=VEHICLES[cfg.vehicle]

  const render=()=>{
    if(tab==='dashboard') return <Dashboard setPage={setTab} setSport={setSport}/>
    switch(tab){
      case 'standings': return <Standings sport={sport} cfg={cfg}/>
      case 'races':     return <Races     sport={sport} cfg={cfg}/>
      case 'drivers':   return <Drivers   sport={sport} cfg={cfg}/>
      case 'teams':     return <Teams     sport={sport} cfg={cfg}/>
      case 'circuits':  return <Circuits  sport={sport} cfg={cfg}/>
      case 'analytics': return <Analytics sport={sport} cfg={cfg}/>
      case 'admin':     return <Admin/>
      default: return null
    }
  }

  return (
    <div style={{minHeight:'100vh',background:'var(--bg)',display:'flex',flexDirection:'column'}}>

      {/* TOPBAR */}
      <div style={{background:'var(--bg2)',borderBottom:'1px solid var(--border)',display:'flex',alignItems:'center',padding:'0 24px',height:52,position:'sticky',top:0,zIndex:200,gap:20}}>
        <button onClick={()=>setTab('dashboard')} style={{fontFamily:'var(--display)',fontSize:19,letterSpacing:'0.08em',color:'var(--text)',background:'none',border:'none',cursor:'pointer',flexShrink:0}}>
          MOTO<span style={{color:'var(--c)',filter:`drop-shadow(0 0 6px var(--c))`}}>.</span>DB
        </button>

        {/* Sport pills */}
        <div style={{display:'flex',gap:3,padding:'3px',background:'var(--bg)',borderRadius:8,border:'1px solid var(--border)'}}>
          {Object.values(SPORTS).map(s=>(
            <button key={s.key} onClick={()=>{setSport(s.key);if(tab!=='dashboard')setTab('standings')}} style={{
              padding:'5px 16px',borderRadius:6,
              border:sport===s.key?`1px solid ${s.color}`:'1px solid transparent',
              background:sport===s.key?`${s.color}15`:'transparent',
              color:sport===s.key?s.color:'var(--muted)',
              fontFamily:'var(--mono)',fontWeight:700,fontSize:11,
              letterSpacing:'0.06em',cursor:'pointer',transition:'all .15s',
            }}>{s.label}</button>
          ))}
        </div>

        <div style={{marginLeft:'auto',display:'flex',alignItems:'center',gap:10}}>
          <div style={{width:6,height:6,borderRadius:'50%',background:'var(--c)',animation:cfg.live?'pulse 1s ease infinite':'none',flexShrink:0}}/>
          <span style={{fontSize:11,color:'var(--muted)',fontFamily:'var(--mono)'}}>{cfg.name} · {cfg.year}{cfg.live?' · live':' · mysql'}</span>
        </div>
      </div>

      {/* Racing banner (shows when not on dashboard) */}
      {tab!=='dashboard'&&<RacingBanner cfg={cfg}/>}

      <div style={{display:'flex',flex:1,minHeight:0}}>
        {/* SIDEBAR */}
        <div style={{width:168,background:'var(--bg2)',borderRight:'1px solid var(--border)',padding:'14px 8px',flexShrink:0,position:'sticky',top:tab==='dashboard'?52:52+72,height:`calc(100vh - ${tab==='dashboard'?52:124}px)`,overflowY:'auto'}}>

          <button onClick={()=>setTab('dashboard')} style={{width:'100%',display:'block',padding:'9px 12px',border:'none',borderRadius:7,background:tab==='dashboard'?'var(--c-bg)':'transparent',color:tab==='dashboard'?'var(--c)':'var(--muted)',fontFamily:'var(--sans)',fontSize:13,fontWeight:tab==='dashboard'?700:500,cursor:'pointer',textAlign:'left',marginBottom:10,transition:'all .12s',borderLeft:`3px solid ${tab==='dashboard'?'var(--c)':'transparent'}`}}>
            Dashboard
          </button>

          {/* Sport badge */}
          <div style={{padding:'7px 10px',marginBottom:8,borderRadius:7,background:`${cfg.color}0e`,border:`1px solid ${cfg.color}25`}}>
            <div style={{fontSize:10,color:cfg.color,fontWeight:700,fontFamily:'var(--mono)',letterSpacing:'0.1em'}}>{cfg.name}</div>
            <div style={{fontSize:9,color:'var(--muted)',marginTop:1}}>{cfg.live?'🔴 Jolpica API':`📦 MySQL ${cfg.year}`}</div>
          </div>

          {TABS.filter(t=>t.id!=='dashboard').map(t=>(
            <button key={t.id} onClick={()=>setTab(t.id)} style={{width:'100%',display:'block',padding:'9px 12px',border:'none',borderRadius:7,background:tab===t.id?'var(--c-bg)':'transparent',color:tab===t.id?'var(--c)':'var(--muted)',fontFamily:'var(--sans)',fontSize:13,fontWeight:tab===t.id?700:500,cursor:'pointer',textAlign:'left',marginBottom:2,transition:'all .12s',borderLeft:`3px solid ${tab===t.id?'var(--c)':'transparent'}`}}>
              {t.label}
            </button>
          ))}

          {/* Mini vehicle at bottom */}
          <div style={{marginTop:20,paddingTop:16,borderTop:'1px solid var(--border)',opacity:.35}}>
            <VComp color={cfg.color} size={120}/>
          </div>
        </div>

        {/* MAIN */}
        <main style={{flex:1,overflowY:'auto'}}>
          <div style={{padding:tab==='dashboard'?0:'28px 32px',maxWidth:tab==='dashboard'?1200:1000}}>
            {tab!=='dashboard'&&(
              <div style={{display:'flex',alignItems:'baseline',gap:14,marginBottom:26}}>
                <h1 style={{fontFamily:'var(--display)',fontWeight:400,fontSize:38,letterSpacing:'0.04em',color:'var(--text)',lineHeight:1}}>
                  {TABS.find(t=>t.id===tab)?.label?.toUpperCase()}
                </h1>
                <span style={{fontSize:12,color:'var(--muted)',fontFamily:'var(--mono)'}}>{cfg.name} {cfg.year}</span>
                {cfg.live&&tab!=='analytics'&&tab!=='admin'&&<Live/>}
              </div>
            )}
            {render()}
          </div>
        </main>
      </div>
    </div>
  )
}
